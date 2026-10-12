# CLI Tools with clix & kong

## Overview

`github.com/lrstanley/clix/v2` is a wrapper around [kong](https://github.com/alecthomas/kong) that provides opinionated defaults for building CLI applications: structured logging via `log/slog`, version/build info flags, `.env` file loading, markdown documentation generation, and and more. All features are opt-in when using `clix.New`, or enabled by default with `clix.NewWithDefaults`.

For the full list of supported struct tags, see the [kong documentation](https://github.com/alecthomas/kong#supported-tags).

## When to Use

- Building any CLI application that needs flags, env vars, logging, or version output.
- Projects that want structured `slog`-based logging wired in automatically.
- Applications that need to generate their own flag/usage documentation as markdown.

## When Not to Use

- Libraries that should not call `os.Exit` or parse `os.Args`.
- Applications that already use a different CLI framework (cobra, urfave/cli, etc.) and have no reason to migrate.

## Simple Single-Struct CLI

For small applications, define all flags in a single struct. clix parses the struct tags via kong and populates the fields from CLI flags and environment variables.

```go
type Flags struct {
    Name string `name:"name" env:"NAME" default:"world" help:"name to print"`
}

// Can also be invoked inside of main, especially if you have required flags and are writing tests in the main package.
var cli = clix.NewWithDefaults[Flags]()

func main() {
    ctx := context.Background()
    logger := cli.GetLogger()

    if cli.Debug {
        logger.DebugContext(ctx, "thinking really hard...")
    }

    logger.InfoContext(ctx, "hello", "name", cli.Flags.Name)
}
```

## Multi-Struct Flags Across Module Boundaries

For larger applications, embed configuration structs from other packages using kong's `embed`, `prefix`, and `envprefix` tags. Each struct owns its own flag namespace.

```go
// internal/models/flags.go

type Flags struct {
    HTTP     ConfigHTTP     `embed:"" group:"HTTP Server options" prefix:"http."     envprefix:"HTTP_"`
    Database ConfigDatabase `embed:"" group:"Database options"    prefix:"database." envprefix:"DATABASE_"`
    Github   ConfigGithub   `embed:"" group:"Github options"      prefix:"github."   envprefix:"GITHUB_"`
}

type ConfigDatabase struct {
    URL string `env:"URL" required:"" help:"database connection url"`
}

type ConfigHTTP struct {
    BaseURL  string `env:"BASE_URL"  name:"base-url"  default:"http://localhost:8080" help:"base url for the HTTP server"`
    BindAddr string `env:"BIND_ADDR" name:"bind-addr"  default:":8080" required:"" help:"ip:port pair to bind to"`
}

type ConfigGithub struct {
    Token       string `env:"TOKEN"         name:"token"         required:"" help:"GitHub access token"`
    SyncOnStart bool   `env:"SYNC_ON_START" name:"sync-on-start" help:"sync all data from GitHub on startup"`
}
```

This produces flags like `--http.base-url`, `--database.url`, `--github.token`, and environment variables like `HTTP_BASE_URL`, `DATABASE_URL`, `GITHUB_TOKEN`. The `group` tag creates labeled sections in `--help` output.

## Multiple Commands

### Inline Commands with `Context.Command()`

For simple applications, use inline nested structs with the `cmd` tag and route execution using `cli.Context.Command()`.

```go
type Flags struct {
    Serve struct {
        Addr string `name:"addr" default:":8080" help:"address to listen on"`
    } `cmd:"" help:"Start the HTTP server."`

    Migrate struct {
        Direction string `arg:"" enum:"up,down" help:"migration direction"`
    } `cmd:"" help:"Run database migrations."`

    Status struct{} `cmd:"" default:"" help:"Show application status."`
}

var cli = clix.NewWithDefaults[Flags]()

func main() {
    ctx := context.Background()
    logger := cli.GetLogger()

    switch cli.Context.Command() {
    case "serve":
        logger.InfoContext(ctx, "starting server", "addr", cli.Flags.Serve.Addr)
    case "migrate <direction>":
        logger.InfoContext(ctx, "running migration", "direction", cli.Flags.Migrate.Direction)
    case "status":
        logger.InfoContext(ctx, "all systems operational")
    default:
        logger.ErrorContext(ctx, "unknown command", "command", cli.Context.Command())
    }
}
```

The `default:""` tag on `Status` makes it the command that runs when no subcommand is specified. Positional arguments use the `arg:""` tag.

### Separate Command Structs with `Run()` Methods

For larger applications, define each command as its own struct type with a `Run()` method. Kong automatically dispatches to the matched command's `Run()` method when you call `cli.Context.Run(bindings...)`. Any parameters in the `Run()` signature are resolved via dependency injection -- clix automatically binds `*clix.CLI[T]`, `*slog.Logger`, `*clix.AppInfo`, and `*clix.Version`.

```go
type Flags struct {
    Serve   ServeCmd   `cmd:"" help:"Start the HTTP server."`
    Migrate MigrateCmd `cmd:"" help:"Run database migrations."`
    Status  StatusCmd  `cmd:"" default:"" help:"Show application status."`
}

var cli = clix.NewWithDefaults[Flags]()

func main() {
    err := cli.Context.Run()
    cli.Context.FatalIfErrorf(err)
}
```

Each command struct defines its own flags and a `Run()` method. Arguments to `Run()` are injected by kong from anything registered via `kong.Bind()` or passed to `ctx.Run()`.

```go
type ServeCmd struct {
    Addr string `name:"addr" default:":8080" help:"address to listen on"`
}

func (cmd *ServeCmd) Run(logger *slog.Logger) error {
    ctx := context.Background()
    logger.InfoContext(ctx, "starting server", "addr", cmd.Addr)
    return http.ListenAndServe(cmd.Addr, nil)
}

type MigrateCmd struct {
    Direction string `arg:"" enum:"up,down" help:"migration direction"`
    Steps     int    `name:"steps" default:"0" help:"number of steps (0 = all)"`
}

func (cmd *MigrateCmd) Run(logger *slog.Logger) error {
    ctx := context.Background()
    logger.InfoContext(ctx, "running migration", "direction", cmd.Direction, "steps", cmd.Steps)
    return nil
}

type StatusCmd struct{}

func (cmd *StatusCmd) Run(logger *slog.Logger) error {
    slog.Info("all systems operational")
    return nil
}
```

This pattern scales well because each command is self-contained -- it can live in its own file or package, carry its own dependencies, and be tested independently. The `main()` function stays minimal regardless of how many commands exist.

## Version and Build Info

Define top-level variables that the build system injects via `-ldflags`, then pass them into `clix.WithAppInfo`.

```go
var (
    version = "master"
    commit  = "HEAD"
    date    = "-"
)

var cli = clix.NewWithDefaults(
    clix.WithAppInfo[Flags](clix.AppInfo{
        Name:    "myapp",
        Version: version,
        Commit:  commit,
        Date:    date,
        Links: clix.GithubLinks(
            "github.com/user/myapp", "master", "https://myapp.dev",
        ),
    }),
)
```

Build with ldflags to stamp values at compile time:

```bash
go build -ldflags "-X main.version=1.2.3 -X main.commit=$(git rev-parse HEAD) -X main.date=$(date -u +%Y-%m-%dT%H:%M:%SZ)" -o myapp .
```

If `WithAppInfo` is not used, clix automatically reads Go's `debug.BuildInfo` for VCS revision, date, and module path. The `--version` flag prints human-readable output; `--version-json` prints JSON.

`GithubLinks` generates an opinionated set of links (homepage, issues, support, contributing, security) that appear in both version and help output.

## Using the Built-in Logger

When the logging plugin is enabled (default in `NewWithDefaults`), access the logger after parsing.

```go
var cli = clix.NewWithDefaults[Flags]()

func main() {
    ctx := context.Background()
    logger := cli.GetLogger()

    logger.InfoContext(ctx, "server starting", "addr", cli.Flags.Addr)
    logger.DebugContext(ctx, "verbose detail that only shows with --debug or --log.level=debug")
    logger.WarnContext(ctx, "approaching rate limit", "usage", 0.92)
    logger.ErrorContext(ctx, "startup failed", "error", err)
}
```

When `--debug` (`-D`) is passed, the log level is forced to `debug` regardless of `--log.level`. The global `slog.Default()` is also set, so third-party libraries using `slog` will inherit the same handler.

## Generating Markdown Documentation

clix includes a hidden `generate-markdown` command that produces markdown documentation of all flags and commands.

```bash
./myapp generate-markdown > USAGE.md
```

Control the output with environment variables:

| Environment Variable | Description | Default |
| --- | --- | --- |
| `CLIX_TEMPLATE_PATH` | Directory of Go template files to override built-in markdown templates | built-in |
| `CLIX_OUTPUT_PATH` | File path to write output, or `-` for stdout | `-` |

You can also generate markdown programmatically:

```go
md, err := cli.GenerateMarkdown()
if err != nil {
    log.Fatal(err)
}
fmt.Println(md)
```

A common pattern is to wire this into a `Makefile`:

```makefile
prepare:
    go run . generate-markdown > USAGE.md
```

## Passing Custom Kong Options

Use `clix.WithKongOptions` to pass any kong option through to the underlying parser.

```go
var cli = clix.NewWithDefaults(
    clix.WithKongOptions[Flags](
        kong.Name("myapp"),
        kong.UsageOnError(),
    ),
)
```

## Context Injection

clix can inject itself into a `context.Context` or as HTTP middleware, useful for passing the parsed CLI state to handlers or services.

```go
ctx := cli.NewContext(context.Background())

// Later, in a handler or service:
parsed := clix.FromContext[Flags](ctx)
logger := parsed.GetLogger()
```

As HTTP middleware:

```go
mux := http.NewServeMux()
handler := cli.NewHTTPContext(mux)
http.ListenAndServe(":8080", handler)
```

## Quick Reference

| Feature | How |
| --- | --- |
| Parse with all defaults | `clix.NewWithDefaults[T]()` |
| Parse with no defaults | `clix.New[T]()` |
| Access parsed flags | `cli.Flags.FieldName` |
| Check debug mode | `cli.Debug` |
| Get logger | `cli.GetLogger()` |
| Get version info | `cli.GetVersion()` |
| Route subcommands | `cli.Context.Command()` |
| Generate markdown | `./app generate-markdown` |
| Set app metadata | `clix.WithAppInfo[T](clix.AppInfo{...})` |
| Load .env files | enabled by default, or `clix.WithEnvFiles[T]("path")` |
| Custom kong options | `clix.WithKongOptions[T](...)` |
| Kong struct tag docs | [github.com/alecthomas/kong#supported-tags](https://github.com/alecthomas/kong#supported-tags) |
