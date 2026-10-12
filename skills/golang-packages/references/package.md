# pkgsite-cli package

Inspect a single Go package on pkg.go.dev.

## Usage

```bash
pkgsite-cli package [flags] <package>[@version]
```

Requires exactly one positional argument: the package import path, optionally
followed by `@version`.

## Flags

### Shared flags

| Flag | Default | Description |
| --- | --- | --- |
| `-json` | off | Output a JSON `packageResult` object |
| `-limit` | 25 | Max symbols or imported-by entries to fetch |
| `-server` | `https://pkg.go.dev` | API server base URL |
| `-timeout` | 30s | Request timeout |
| `-x` | off | Print fetched URLs to stderr |

### Package-specific flags

| Flag | Default | Description |
| --- | --- | --- |
| `-doc` | (none) | Render documentation; value is `text`, `md`, or `html` |
| `-examples` | off | Include examples in rendered docs (requires `-doc`) |
| `-imports` | off | Include direct import paths in the response |
| `-imported-by` | off | List packages that import this package (paginated) |
| `-symbols` | off | List exported symbols (paginated) |
| `-licenses` | off | Include license metadata |
| `-module` | (none) | Disambiguate when the package path exists in multiple modules |
| `-goos` | (none) | Target GOOS for platform-specific docs (e.g. `linux`, `windows`) |
| `-goarch` | (none) | Target GOARCH for platform-specific docs (e.g. `amd64`, `arm64`) |

## API Endpoint

Maps to `GET /v1beta/package/{path}` plus optional supplementary endpoints:

| Flag | Endpoint |
| --- | --- |
| (base) | `/v1beta/package/{path}` |
| `-symbols` | `/v1beta/symbols/{path}` |
| `-imported-by` | `/v1beta/imported-by/{path}` |

Query parameters mirror the flags: `version`, `module`, `doc`, `examples`,
`imports`, `licenses`, `goos`, `goarch`, `limit`, `token`.

## JSON Output Shape

With `-json`, stdout contains a `packageResult`:

```go
type packageResult struct {
    Package    *Package                          // always present on success
    Symbols    *PaginatedResponse[Symbol]        // with -symbols
    ImportedBy *PackageImportedBy                // with -imported-by
}

type Package struct {
    Path              string
    Name              string
    Synopsis          string
    IsRedistributable bool
    ModulePath        string
    Version           string
    IsLatest          bool
    IsStandardLibrary bool
    GOOS              string
    GOARCH            string
    Docs              string    // with -doc
    Imports           []string  // with -imports
    Licenses          []License // with -licenses
}

type License struct {
    Types    []string
    FilePath string
}

type Symbol struct {
    Name     string
    Kind     string   // e.g. "func", "type", "const", "var"
    Synopsis string   // one-line declaration when available
    Parent   string   // enclosing type, if any
}

type PackageImportedBy struct {
    ModulePath string
    Version    string
    ImportedBy PaginatedResponse[string] // importer package paths
}

type PaginatedResponse[T] struct {
    Items         []T
    Total         int
    NextPageToken string
}
```

JSON field names use camelCase (e.g. `modulePath`, `isLatest`, `importedBy`).

## Text Output

Default text mode prints package header fields, then optional sections:

```
github.com/google/go-cmp/cmp
  Name:     cmp
  Module:   github.com/google/go-cmp
  Version:  v0.7.0 (latest)
  Synopsis: Package cmp determines equality of values.
  Context:  all/all

Symbols:
  type Option interface{}
  func Equal(x, y any, opts ...Option) bool
  Showing 25 of 60. Use --limit=N to see more.
```

Pagination hints appear when `-limit` truncates results.

## Examples

### Basic metadata

```bash
pkgsite-cli package github.com/google/go-cmp/cmp
pkgsite-cli package github.com/google/go-cmp/cmp@v0.6.0
```

### Exported symbols

```bash
pkgsite-cli package -symbols github.com/google/go-cmp/cmp
pkgsite-cli package -symbols -limit 100 github.com/google/go-cmp/cmp
```

### Reverse dependencies

```bash
pkgsite-cli package -imported-by github.com/google/go-cmp/cmp
```

### Rendered documentation

```bash
pkgsite-cli package -doc=text github.com/google/go-cmp/cmp
pkgsite-cli package -doc=md -examples golang.org/x/sync/errgroup
```

### Imports and licenses

```bash
pkgsite-cli package -imports -licenses github.com/google/uuid
```

### Platform-specific documentation

```bash
pkgsite-cli package -doc=text -goos=linux -goarch=amd64 syscall
```

### Disambiguate module path

When a package path is provided by multiple modules, the API returns candidates.
Retry with `-module`:

```bash
pkgsite-cli package -module=example.com/a/b example.com/a/b/c
```

The error message lists suggested `--module=` values.

### JSON for scripting

```bash
pkgsite-cli package -json -symbols github.com/google/go-cmp/cmp \
  | jq '.symbols.items[].synopsis'

pkgsite-cli package -json -imported-by -limit 50 github.com/google/uuid \
  | jq '.importedBy.importedBy.items[]'
```

### Debug API URLs

```bash
pkgsite-cli package -x -symbols github.com/google/go-cmp/cmp 2>&1
```

URLs print to stderr; response prints to stdout.

## Combining Flags

Multiple enrichment flags can be used together:

```bash
pkgsite-cli package -symbols -imported-by -imports -licenses \
  github.com/google/go-cmp/cmp
```

Each optional section triggers a separate API call. Use only the flags you need
to minimize latency.

## When to Use

- Inspecting a known package path on pkg.go.dev
- Listing exported API surface (`-symbols`) before adopting a dependency
- Finding who imports a package (`-imported-by`) for migration or deprecation analysis
- Fetching rendered godoc-style text without downloading the module

## When Not to Use

- Local packages already in `GOMODCACHE` (use `go doc`)
- Module-level version lists or vulnerability reports (use `pkgsite-cli module`)
- Fuzzy package discovery (use `pkgsite-cli search`)

## Error Handling

| Exit code | Meaning |
| --- | --- |
| 0 | Success |
| 1 | API or network error |
| 2 | Usage error (wrong argument count) |

In `-json` mode, errors are written to stdout as an API error object:

```json
{
  "code": 400,
  "message": "ambiguous package path",
  "candidates": [
    { "modulePath": "example.com/a", "packagePath": "example.com/a/b/c" }
  ]
}
```

Timeout errors suggest increasing `-timeout` or reducing `-limit`.
