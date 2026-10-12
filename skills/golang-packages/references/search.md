# pkgsite-cli search

Search pkg.go.dev for Go packages matching a query.

## Usage

```bash
pkgsite-cli search [flags] <query>
```

The query is one or more words. Multiple words after flags are joined with
spaces into a single query string.

## Flags

### Shared flags

| Flag | Default | Description |
| --- | --- | --- |
| `-json` | off | Output a JSON `PaginatedResponse[SearchResult]` |
| `-limit` | 25 | Max search results to return |
| `-server` | `https://pkg.go.dev` | API server base URL |
| `-timeout` | 30s | Request timeout |
| `-x` | off | Print fetched URLs to stderr |

### Search-specific flags

| Flag | Default | Description |
| --- | --- | --- |
| `-symbol` | (none) | Search for packages declaring a specific symbol name |

## API Endpoint

Maps to `GET /v1beta/search?q={query}` with optional `symbol`, `limit`, and
`token` query parameters.

## JSON Output Shape

With `-json`, stdout contains:

```go
type PaginatedResponse[SearchResult] struct {
    Items         []SearchResult
    Total         int
    NextPageToken string
}

type SearchResult struct {
    PackagePath string
    ModulePath  string
    Version     string
    Synopsis    string
}
```

Example:

```json
{
  "items": [
    {
      "packagePath": "github.com/google/uuid",
      "modulePath": "github.com/google/uuid",
      "version": "v1.6.0",
      "synopsis": "Package uuid generates and inspects UUIDs."
    }
  ],
  "total": 1000,
  "nextPageToken": "..."
}
```

The CLI auto-paginates up to `-limit` items. Use the REST API directly with
`token` for manual pagination beyond the CLI limit.

## Text Output

```
github.com/google/uuid
  Module:   github.com/google/uuid@v1.6.0
  Synopsis: Package uuid generates and inspects UUIDs.

github.com/pborman/uuid
  Module:   github.com/pborman/uuid@v1.2.1
  Synopsis: The uuid package generates and inspects UUIDs.

  Showing 2 of 1000. Use --limit=N to see more.
```

When no results match, text mode prints `No results.`

## Examples

### Basic search

```bash
pkgsite-cli search uuid
pkgsite-cli search "structured logging"
pkgsite-cli search http router middleware
```

Multi-word queries do not require quotes unless the shell would split them.

### Limit results

```bash
pkgsite-cli search -limit 5 uuid
pkgsite-cli search -limit 1 "go-cmp"
```

Flags must appear **before** the query argument.

### Symbol search

Find packages that export a symbol with a given name:

```bash
pkgsite-cli search -symbol Equal github.com/google/go-cmp/cmp
pkgsite-cli search -symbol Context context
```

The `-symbol` value is the bare symbol name (not a qualified path).

### JSON for scripting

```bash
# top 10 package paths matching "redis"
pkgsite-cli search -json -limit 10 redis \
  | jq -r '.items[].packagePath'

# full result metadata
pkgsite-cli search -json -limit 3 "log/slog" \
  | jq '.items[] | {path: .packagePath, module: .modulePath, version: .version}'
```

Pipe into `pkgsite-cli package` for deeper inspection:

```bash
pkgsite-cli search -json -limit 1 uuid \
  | jq -r '.items[0].packagePath' \
  | xargs -I{} pkgsite-cli package -symbols {}
```

### Debug API URLs

```bash
pkgsite-cli search -x -limit 2 uuid 2>&1
```

## Pagination Behavior

The CLI fetches pages until it reaches `-limit` items or exhausts results.
Text output shows `Showing N of M` when truncated. To retrieve more than the
CLI limit in application code, call the REST API with `nextPageToken` from the
JSON response. See `references/api.md`.

Default `-limit` is 25 when unset or zero.

## When to Use

- Discovering candidate packages for a task or library category
- Finding implementations of a named symbol across the ecosystem
- Quick exploration before running `go get` or adding a dependency

## When Not to Use

- Inspecting a known package path (use `pkgsite-cli package`)
- Listing all versions or vulnerabilities for a known module (use `pkgsite-cli module`)
- Searching local module cache (use `go list -m all` or IDE tooling)

## Error Handling

| Exit code | Meaning |
| --- | --- |
| 0 | Success (including zero results) |
| 1 | API or network error |
| 2 | Usage error (missing query) |

In `-json` mode, errors are written to stdout as structured API error objects.
