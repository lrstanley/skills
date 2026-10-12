# Configuration

## Config File Location

Use `os.UserConfigDir()` with the application name as a subdirectory:

```go
import (
    "os"
    "path/filepath"
)

const AppName = "myapp"

func ConfigPath() (string, error) {
    dir, err := os.UserConfigDir()
    if err != nil {
        return "", fmt.Errorf("user config dir: %w", err)
    }
    return filepath.Join(dir, AppName, "config.json"), nil
}

// Or -- simpler but less flexible:
var ConfigPath = sync.OnceValue(func() string {
    dir, err := os.UserConfigDir()
    if err != nil {
        panic(fmt.Printf("unable to get user config dir: %v", err))
    }
    return filepath.Join(dir, AppName, "config.json")
})
```

This resolves to (unless changed with `XDG_*` environment variables):

- Linux: `~/.config/myapp/config.json`
- macOS: `~/Library/Application Support/myapp/config.json`
- Windows: `%AppData%\myapp\config.json`

### Other Standard Directories

```go
os.UserConfigDir()  // configuration files
os.UserCacheDir()   // cache data (safe to delete)
os.UserHomeDir()    // home directory (avoid storing app data here directly)
```

## Should do

- Resolve paths with `os.UserConfigDir()`, `os.UserCacheDir()`, and `filepath.Join`
  so Linux, macOS, and Windows stay correct without hardcoding `~/.config` or `%AppData%`.
- Put files under a dedicated subdirectory named after the app, and create that
  directory with restrictive permissions (e.g. `0750` for directories, and `0640`
  for files) before writing.
- Put durable settings in the config dir and ephemeral or regenerable data in the
  cache dir; document where each lives for users (for example in `--help` or the
  README).
- Validate config on load, return clear errors, and version or migrate the format
  when the schema changes instead of failing silently or corrupting data.
- Support environment variables or command line flags for configuration that is
  likely to be changed by the user and/or warrants a per-terminal-session override.

## Should not do

- Hardcode platform paths or assume `$HOME` layout; bypasses `XDG_CONFIG_HOME` and
  equivalent conventions on other OSes.
- Store large caches, logs, or binary blobs in the config directory; use cache dir,
  state dir, or a logging path appropriate to the platform.
- Panic or exit without explanation when config is missing or invalid; prefer
  recoverable defaults or actionable messages for interactive use.
- Persist secrets in plain JSON or YAML without considering OS keychain or credential
  helpers when the threat model requires it.
