# pkg.go.dev v1beta REST API

Programmatic alternative to pkgsite-cli. Same data, direct HTTP access for
application integrations, CI pipelines, and custom tooling.

## Documentation

| Resource | URL |
| --- | --- |
| Interactive API reference | https://pkg.go.dev/api |
| OpenAPI specification | https://pkg.go.dev/v1beta/openapi.yaml |
| Blog introduction | https://go.dev/blog/pkgsite-api |
| Reference CLI source | https://github.com/golang/pkgsite/tree/master/cmd/internal/pkgsite-cli |

The API is currently under `/v1beta`. A stable `/v1` release is planned after
community feedback. The REST contract is intended to remain backward compatible;
the pkgsite-cli command interface is **not** guaranteed stable.

## Architecture

- Stateless, GET-only endpoints
- Designed for caching and CDN delivery
- JSON request/response bodies
- User-Agent: set a descriptive value in custom clients (`pkgsite-cli` uses `pkgsite-cli/v1`)

Base URL: `https://pkg.go.dev/v1beta/`

## Core Endpoints

| Endpoint | Description |
| --- | --- |
| `GET /v1beta/package/{path}` | Package metadata; optional docs, imports, licenses |
| `GET /v1beta/module/{path}` | Module metadata; optional readme, licenses |
| `GET /v1beta/versions/{path}` | Published versions of a module |
| `GET /v1beta/packages/{path}` | Packages contained in a module |
| `GET /v1beta/search?q={query}` | Search packages by query |
| `GET /v1beta/symbols/{path}` | Exported symbols in a package |
| `GET /v1beta/imported-by/{path}` | Packages that import a given package |
| `GET /v1beta/vulns/{path}` | Vulnerabilities for a module or package |

Path segments use the full import path (slashes are URL path segments).

## Version Parameter

Endpoints that accept a version use the `version` query parameter:

| Form | Example | Notes |
| --- | --- | --- |
| Semver tag | `?version=v1.2.3` | Specific release |
| Branch | `?version=master` or `?version=main` | Resolves to pseudo-version |
| Omitted | (none) | Latest tagged version |

```bash
curl -s 'https://pkg.go.dev/v1beta/package/github.com/google/go-cmp/cmp?version=master' \
  | jq '{path, version}'
```

Custom branch names other than `master` and `main` are not supported.

## Module Disambiguation

Unlike the pkg.go.dev web UI (which applies the "longest module path" rule), the
API requires an unambiguous module when a package path exists in multiple modules.

When ambiguous, the API returns an error with `candidates`:

```json
{
  "code": 400,
  "message": "ambiguous package path",
  "candidates": [
    { "modulePath": "example.com/a", "packagePath": "example.com/a/b/c" },
    { "modulePath": "example.com/a/b", "packagePath": "example.com/a/b/c" }
  ]
}
```

Retry with `?module=example.com/a/b`.

pkgsite-cli equivalent:

```bash
pkgsite-cli package -module=example.com/a/b example.com/a/b/c
```

## Pagination

List endpoints return paginated responses:

```json
{
  "items": [...],
  "total": 1000,
  "nextPageToken": "abc123"
}
```

Query parameters:

| Parameter | Description |
| --- | --- |
| `limit` | Max items per page |
| `token` | Page token from a previous response's `nextPageToken` |

pkgsite-cli auto-paginates up to `-limit` and discards the token. For full
control, call the API directly:

```bash
# first page
curl -s 'https://pkg.go.dev/v1beta/search?q=uuid&limit=10' | jq .

# next page (token from previous response)
curl -s 'https://pkg.go.dev/v1beta/search?q=uuid&limit=10&token=TOKEN' | jq .
```

## Package Endpoint Query Parameters

`GET /v1beta/package/{path}`

| Parameter | Values | Description |
| --- | --- | --- |
| `version` | semver or branch | Target version |
| `module` | module path | Disambiguate module |
| `doc` | `text`, `md`, `html` | Rendered documentation |
| `examples` | `true` | Include examples (with `doc`) |
| `imports` | `true` | Direct import paths |
| `licenses` | `true` | License metadata |
| `goos` | GOOS value | Platform-specific docs |
| `goarch` | GOARCH value | Platform-specific docs |

## Module Endpoint Query Parameters

`GET /v1beta/module/{path}`

| Parameter | Values | Description |
| --- | --- | --- |
| `version` | semver or branch | Target version |
| `readme` | `true` | Include README |
| `licenses` | `true` | License metadata |

## Search Query Parameters

`GET /v1beta/search`

| Parameter | Description |
| --- | --- |
| `q` | Search query (required) |
| `symbol` | Filter by exported symbol name |
| `limit` | Page size |
| `token` | Pagination token |

## Example Requests

### Package metadata

```bash
curl -s https://pkg.go.dev/v1beta/package/github.com/google/go-cmp/cmp | jq .
```

### Module versions

```bash
curl -s https://pkg.go.dev/v1beta/versions/github.com/google/go-cmp | jq .
```

### Search

```bash
curl -s 'https://pkg.go.dev/v1beta/search?q=uuid&limit=5' | jq '.items[].packagePath'
```

### Symbols

```bash
curl -s 'https://pkg.go.dev/v1beta/symbols/github.com/google/go-cmp/cmp?limit=10' | jq .
```

### Reverse dependencies

```bash
curl -s 'https://pkg.go.dev/v1beta/imported-by/github.com/google/go-cmp/cmp?limit=10' | jq .
```

### Vulnerabilities

```bash
curl -s 'https://pkg.go.dev/v1beta/vulns/github.com/gin-gonic/gin?version=v1.9.1' | jq .
```

## Error Responses

Non-200 responses return JSON error objects:

```json
{
  "code": 404,
  "message": "module not found",
  "fixes": ["check the module path spelling"]
}
```

Fields:

| Field | Description |
| --- | --- |
| `code` | HTTP status code |
| `message` | Human-readable error |
| `fixes` | Suggested remediation steps |
| `candidates` | Module candidates for ambiguous paths |

## Mapping CLI to API

| pkgsite-cli | API |
| --- | --- |
| `pkgsite-cli package PATH` | `GET /v1beta/package/PATH` |
| `pkgsite-cli package -symbols PATH` | `GET /v1beta/symbols/PATH` |
| `pkgsite-cli package -imported-by PATH` | `GET /v1beta/imported-by/PATH` |
| `pkgsite-cli module PATH` | `GET /v1beta/module/PATH` |
| `pkgsite-cli module -versions PATH` | `GET /v1beta/versions/PATH` |
| `pkgsite-cli module -packages PATH` | `GET /v1beta/packages/PATH` |
| `pkgsite-cli module -vulns PATH` | `GET /v1beta/vulns/PATH` |
| `pkgsite-cli search QUERY` | `GET /v1beta/search?q=QUERY` |

Use `-server` to point pkgsite-cli at a custom base URL (must serve the same
`/v1beta/*` paths).

## Building a Custom Client

There is no official Go SDK. The pkgsite-cli `client` package is internal to
`golang.org/x/pkgsite` and duplicates API types locally to stay stdlib-only.

Recommended approach for new tools:

1. Read the [OpenAPI spec](https://pkg.go.dev/v1beta/openapi.yaml) for exact schemas
2. Use `net/http` with context timeouts and a descriptive User-Agent
3. Handle pagination via `nextPageToken`
4. Handle ambiguous paths via `candidates` in error responses

Minimal Go pattern:

```go
func getPackage(ctx context.Context, path string) (*Package, error) {
    u := "https://pkg.go.dev/v1beta/package/" + path
    req, err := http.NewRequestWithContext(ctx, http.MethodGet, u, nil)
    if err != nil {
        return nil, err
    }
    req.Header.Set("User-Agent", "my-tool/1.0")

    resp, err := http.DefaultClient.Do(req)
    if err != nil {
        return nil, err
    }
    defer resp.Body.Close()

    if resp.StatusCode != http.StatusOK {
        return nil, fmt.Errorf("pkg.go.dev: HTTP %d", resp.StatusCode)
    }

    var pkg Package
    return &pkg, json.NewDecoder(resp.Body).Decode(&pkg)
}
```

For production use, add structured error parsing, retries with backoff for
transient failures, and respect rate limits.

## When to Use the API vs CLI

| Use CLI | Use REST API |
| --- | --- |
| Ad-hoc terminal exploration | Application or service integration |
| Shell scripts with `-json` and `jq` | Fine-grained pagination control |
| Quick one-off lookups | CI/CD dependency auditing pipelines |
| Debugging with `-x` URL tracing | Custom caching or batch processing |

Both access the same pkg.go.dev backend data.
