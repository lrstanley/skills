# pkgsite-cli module

Inspect a Go module on pkg.go.dev.

## Usage

```bash
pkgsite-cli module [flags] <module>[@version]
```

Requires exactly one positional argument: the module path, optionally followed
by `@version`.

## Flags

### Shared flags

| Flag | Default | Description |
| --- | --- | --- |
| `-json` | off | Output a JSON `moduleResult` object |
| `-limit` | 25 | Max items for versions, vulns, or packages lists |
| `-server` | `https://pkg.go.dev` | API server base URL |
| `-timeout` | 30s | Request timeout |
| `-x` | off | Print fetched URLs to stderr |

### Module-specific flags

| Flag | Default | Description |
| --- | --- | --- |
| `-readme` | off | Include README contents |
| `-licenses` | off | Include license metadata |
| `-versions` | off | List published versions (paginated) |
| `-vulns` | off | List known vulnerabilities (paginated) |
| `-packages` | off | List packages contained in the module (paginated) |

## API Endpoints

| Flag | Endpoint |
| --- | --- |
| (base) | `/v1beta/module/{path}` |
| `-versions` | `/v1beta/versions/{path}` |
| `-vulns` | `/v1beta/vulns/{path}` |
| `-packages` | `/v1beta/packages/{path}` |

Query parameters: `version`, `readme`, `licenses`, `limit`, `token`.

## JSON Output Shape

With `-json`, stdout contains a `moduleResult`:

```go
type moduleResult struct {
    Module   *Module                                   // always present on success
    Versions *PaginatedResponse[VersionResponse]       // with -versions
    Vulns    *PaginatedResponse[Vulnerability]         // with -vulns
    Packages *PaginatedResponse[ModulePackageResponse] // with -packages
}

type Module struct {
    Path              string
    Version           string
    CommitTime        time.Time
    IsLatest          bool
    IsRedistributable bool
    IsStandardLibrary bool
    HasGoMod          bool
    RepoURL           string
    GoModContents     string    // when included by API
    Readme            *Readme     // with -readme
    Licenses          []License   // with -licenses
}

type Readme struct {
    Filepath string
    Contents string
}

type VersionResponse struct {
    Version string
}

type ModulePackageResponse struct {
    Path     string
    Synopsis string
}

type Vulnerability struct {
    ID           string
    Summary      string
    Details      string
    FixedVersion string
}
```

## Text Output

Default text mode prints module header fields, then optional sections:

```
github.com/google/go-cmp
  Version:          v0.7.0 (latest)
  Repository:       https://github.com/google/go-cmp
  Has go.mod:       yes
  Redistributable:  yes

Versions:
  v0.7.0
  v0.6.0
  v0.5.9
  Showing 25 of 18. Use --limit=N to see more.

Packages:
  github.com/google/go-cmp/cmp             Package cmp determines equality of values.
  github.com/google/go-cmp/cmp/cmpopts     Package cmpopts provides common options...
```

Vulnerability entries include ID, summary or details, and fixed version when known.

## Examples

### Basic module metadata

```bash
pkgsite-cli module github.com/google/go-cmp
pkgsite-cli module github.com/google/go-cmp@v0.6.0
pkgsite-cli module std@go1.22.0
```

### List all versions

```bash
pkgsite-cli module -versions github.com/google/go-cmp
pkgsite-cli module -versions -limit 100 github.com/google/go-cmp
```

### List packages in a module

```bash
pkgsite-cli module -packages github.com/google/go-cmp
pkgsite-cli module -packages -versions github.com/google/go-cmp
```

Combining `-packages` and `-versions` fetches both lists concurrently.

### Check vulnerabilities

```bash
pkgsite-cli module -vulns github.com/gin-gonic/gin
pkgsite-cli module -vulns github.com/gin-gonic/gin@v1.9.1
```

Pass `@version` to scope vulnerability lookup to a specific release.

### README and licenses

```bash
pkgsite-cli module -readme github.com/charmbracelet/bubbletea
pkgsite-cli module -licenses github.com/charmbracelet/bubbletea
```

### JSON for scripting

```bash
# latest semver tag
pkgsite-cli module -json -versions -limit 1 github.com/google/go-cmp \
  | jq -r '.versions.items[0].version'

# all package paths in a module
pkgsite-cli module -json -packages github.com/google/go-cmp \
  | jq '.packages.items[].path'

# vulnerability IDs
pkgsite-cli module -json -vulns github.com/gin-gonic/gin \
  | jq '.vulns.items[] | {id, fixedVersion: .fixedVersion}'
```

### Pin to a branch

```bash
pkgsite-cli module -packages github.com/google/go-cmp@master
```

Branch names `master` and `main` resolve to pseudo-versions via the API.

### Debug API URLs

```bash
pkgsite-cli module -x -versions -vulns github.com/google/go-cmp 2>&1
```

## Parallel Fetching

When multiple list flags are set (`-versions`, `-vulns`, `-packages`), the CLI
issues concurrent API requests. Each list respects `-limit` independently.

## When to Use

- Choosing a module version before adding a dependency
- Auditing known vulnerabilities for a module or specific release
- Enumerating subpackages exported by a module
- Reading upstream README or license information without cloning

## When Not to Use

- Package-level symbol or imported-by queries (use `pkgsite-cli package`)
- Searching for unknown package names (use `pkgsite-cli search`)
- Reading `go.mod` from a local checkout (use the filesystem)

## Error Handling

| Exit code | Meaning |
| --- | --- |
| 0 | Success |
| 1 | API or network error |
| 2 | Usage error (wrong argument count) |

In `-json` mode, errors go to stdout as structured API error objects. Increase
`-timeout` for modules with large version lists or many packages.
