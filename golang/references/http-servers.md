# HTTP Servers, Middleware, Routes, REST APIs & HTTP Error Handling

## go-chi: Routing and Middleware

### Router Setup

`github.com/go-chi/chi/v5` is a lightweight, idiomatic HTTP router built entirely on `net/http`. Handlers and middleware are standard `http.Handler` / `http.HandlerFunc` -- nothing chi-specific leaks into your signatures.

```go
import (
    "net/http"

    "github.com/go-chi/chi/v5"
    "github.com/go-chi/chi/v5/middleware"
)

r := chi.NewRouter()

r.Use(
    middleware.Compress(5),
    middleware.Recoverer,
)

r.Get("/", func(w http.ResponseWriter, r *http.Request) {
    w.Write([]byte("ok"))
})

http.ListenAndServe(":8080", r)
```

### Route Patterns and URL Parameters

chi supports named parameters (`{param}`), wildcards (`*`), and regex constraints.

```go
r.Route("/articles", func(r chi.Router) {
    r.Get("/", listArticles)
    r.Post("/", createArticle)
    r.Get("/search", searchArticles)
    r.Get("/{slug:[a-z-]+}", getArticleBySlug)

    r.Route("/{articleID}", func(r chi.Router) {
        r.Use(articleCtx)
        r.Get("/", getArticle)
        r.Put("/", updateArticle)
        r.Delete("/", deleteArticle)
    })
})

func getArticle(w http.ResponseWriter, r *http.Request) {
    id := r.PathValue("articleID")
    // ...
}
```

### Mounting Sub-Routers

`Mount` attaches an independent `http.Handler` at a prefix. The mounted handler receives paths with the prefix stripped.

```go
r.Mount("/admin", adminRouter())

func adminRouter() http.Handler {
    r := chi.NewRouter()
    r.Use(adminOnly)
    r.Get("/", adminIndex)
    r.Get("/accounts", adminListAccounts)
    return r
}
```

### Inline Middleware with `With`

`With` applies middleware to a single endpoint or group without affecting sibling routes.

```go
r.With(paginate).Get("/items", listItems)

r.With(requireAuth).Group(func(r chi.Router) {
    r.Get("/me", getProfile)
    r.Put("/me", updateProfile)
})
```

### Writing Middleware

chi middleware is a plain `func(http.Handler) http.Handler`. No special types required.

```go
func requestTimer(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        start := time.Now()
        next.ServeHTTP(w, r)
        slog.InfoContext(r.Context(), "request completed", "duration", time.Since(start))
    })
}
```

### Compression

Use `middleware.Compress` to gzip responses for clients that accept it. The argument is the compression level (1-9, or `5` as a good default).

```go
r.Use(middleware.Compress(5))
```

### Throttling and Rate Limiting

`middleware.Throttle` caps the number of concurrent in-flight requests. Use `github.com/go-chi/httprate` for per-client rate limiting (requests per window).

```go
import "github.com/go-chi/httprate"

r.Use(middleware.Throttle(100))

r.Use(httprate.LimitByIP(100, time.Minute))

r.Group(func(r chi.Router) {
    r.Use(httprate.LimitByIP(5, time.Minute))
    r.Post("/login", handleLogin)
})
```

### Server Timeouts

Always set `ReadTimeout` and `WriteTimeout` on `http.Server`. Without them, a slow client can hold a connection open indefinitely. Note that `chix.Run` and `chix.RunTLS` set these timeouts for you.

```go
srv := &http.Server{
    Addr:         ":8080",
    Handler:      r,
    ReadTimeout:  10 * time.Second,
    WriteTimeout: 10 * time.Second,
}
```

---

## chix v2: Production HTTP Toolkit

`github.com/lrstanley/chix/v2` builds on top of go-chi, providing production-grade middleware, error handling, structured logging, authentication, graceful shutdown, static file serving, and more. It is opinionated but composable -- use the pieces you need.

### Configuration

`chix.NewConfig()` creates a shared configuration object that is injected into the request context via its `Use()` method. Child middleware and handlers can retrieve and extend it with `chix.GetConfig`. Configuration includes the logger, error resolvers, error handler, API base path, debug modem, and more.

```go
r := chi.NewRouter()
r.Use(
    chix.NewConfig().
        SetLogger(logger).
        SetErrorResolvers(customErrorResolver).
        SetAPIBasePath("/api").
        Use(),
)
```

The config middleware MUST be the first `chix.*` middleware in the chain -- other chix middleware depends on it being present in the context.

### Recommended Middleware Stack

A typical production setup. Order matters -- earlier middleware wraps later ones.

```go
func httpServer(logger *slog.Logger) *http.Server {
    r := chi.NewRouter()
    r.Use(
        chix.NewConfig().
            SetLogger(logger).
            Use(),
        chix.UseDebug(cli.Debug),
        chix.UseRealIP(nil),
        chix.UseContextIP(),
        chix.UseRequestID(),
        chix.UseStripSlashes(),
        chix.UseStructuredLogger(chix.DefaultLogConfig()),
        chix.UseNextURL(),
        chix.UseCrossOriginProtection("*"),
        chix.UseCrossOriginResourceSharing(nil),
        chix.UseHeaders(map[string]string{
            "Content-Security-Policy": "default-src 'self'; img-src * data:; style-src 'self' 'unsafe-inline'; object-src 'none'",
            "X-Frame-Options":         "DENY",
            "X-Content-Type-Options":  "nosniff",
            "Referrer-Policy":         "no-referrer-when-downgrade",
            "Permissions-Policy":      "clipboard-write=(self)",
        }),
    )

    // ...

    return &http.Server{
        Addr:    ":8080",
        Handler: r,
    }
}
```

| Middleware | Purpose |
| --- | --- |
| `chix.NewConfig().Use()` | Injects shared config into context (must be first) |
| `chix.UseDebug(bool)` | Sets debug flag accessible to child handlers |
| `chix.UseRealIP(allowlist)` | Extracts real client IP from proxy headers (with optional trusted-proxy allowlist) |
| `chix.UseContextIP()` | Stores client IP in request context |
| `chix.UseRequestID()` | Generates/propagates a unique request ID |
| `chix.UseStripSlashes()` | Normalizes trailing slashes |
| `chix.UseStructuredLogger(cfg)` | Logs every request/response with `slog` |
| `chix.UseNextURL()` | Parses `?next=` redirect targets |
| `chix.UseCrossOriginProtection(origin)` | CSRF protection |
| `chix.UseCrossOriginResourceSharing(cfg)` | CORS headers |
| `chix.UseHeaders(map)` | Injects static response headers (security headers, etc.) |
| `chix.UsePrivateIP()` | Restricts endpoint to private/internal IPs only |

### Structured Logging

`chix.UseStructuredLogger` logs every request with timing, status code, and any attributes appended during request processing. Within handlers, use `chix.Log*` functions and `chix.AppendLogAttrs` to add context-scoped fields that appear in the final request log line.

```go
r.Use(chix.UseStructuredLogger(chix.DefaultLogConfig()))

r.Use(func(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        chix.AppendLogAttrs(r.Context(), slog.String("tenant", tenantID))
        next.ServeHTTP(w, r)
    })
})

r.Get("/", func(w http.ResponseWriter, r *http.Request) {
    chix.LogInfo(r.Context(), "processing request")
    // ...
})
```

See `references/logging.md` for general slog patterns and log-level guidance.

### Error Handling

chix provides a unified error handling system with automatic error masking, status-code-driven visibility, custom error resolvers, and support for errors that self-declare their visibility.

#### Basic Error Responses

```go
r.Get("/fail", func(w http.ResponseWriter, r *http.Request) {
    chix.ErrorWithCode(w, r, http.StatusInternalServerError, errors.New("database timeout"))
})

r.NotFound(func(w http.ResponseWriter, r *http.Request) {
    chix.ErrorWithCode(w, r, http.StatusNotFound)
})
```

`ErrorWithCode` determines visibility from the status code: `< 500` errors are public (shown to the client), `>= 500` errors are private (masked in the response, logged server-side). Pass multiple errors and they are joined in the response.

#### Error Resolvers

Error resolvers intercept errors before they reach the client, allowing you to remap internal errors to user-friendly responses.

```go
chix.NewConfig().
    SetLogger(logger).
    SetErrorResolvers(customErrorResolver).
    Use()

func customErrorResolver(oerr *chix.ResolvedError) *chix.ResolvedError {
    if oerr.Err == nil || !errors.Is(oerr.Err, sql.ErrNoRows) {
        return nil // nil continues to the next resolver in the chain
    }
    return &chix.ResolvedError{
        Err:        errors.New("resource not found"),
        StatusCode: http.StatusNotFound,
        Visibility: chix.ErrorPublic,
    }
}
```

Returning `nil` from a resolver passes the error to the next resolver. Returning a `*chix.ResolvedError` short-circuits the chain.

#### Exposable Errors

Errors that implement the `chix.ExposableError` interface control their own visibility, regardless of status code.

```go
type SpecialError struct {
    Message string
    Foo     int
}

func (e *SpecialError) Error() string { return e.Message }

func (e *SpecialError) Public() bool { return true }
```

#### Direct Resolved Errors

For full control over status code and visibility, pass a `*chix.ResolvedError` directly.

```go
chix.Error(w, r, &chix.ResolvedError{
    Errs:       []error{errOne, errTwo},
    StatusCode: http.StatusInternalServerError,
    Visibility: chix.ErrorPublic,
})
```

### JSON Responses

```go
r.Get("/api/users", func(w http.ResponseWriter, r *http.Request) {
    chix.JSON(w, r, http.StatusOK, map[string]any{"users": users})
})
```

`chix.JSON` supports `?pretty=true` for human-readable output during development.

### Static Files and SPA Serving

`chix.UseStatic` serves embedded or on-disk files and supports single-page application (SPA) mode, where unmatched routes fall through to `index.html`.

```go
//go:embed all:public
var frontendFS embed.FS

r.With(chix.UseHeaders(map[string]string{
    "Vary":          "Accept-Encoding",
    "Cache-Control": "public, max-age=3600",
})).Mount("/", chix.UseStatic(&chix.StaticConfig{
    FS:     frontendFS,
    Prefix: "/",
    SPA:    true,
    Path:   "public",
}))
```

When building a backend that also serves a frontend, set `SetAPIBasePath` on the chix config so that API routes and static routes coexist cleanly.

```go
chix.NewConfig().
    SetLogger(logger).
    SetAPIBasePath("/api").
    Use()
```

### Authentication with xauth

`github.com/lrstanley/chix/xauth/v2` wraps [markbates/goth](https://github.com/markbates/goth) with encrypted cookie sessions, generic user resolution, and middleware for requiring authentication or injecting auth context.

```go
import (
    "github.com/lrstanley/chix/xauth/v2"
    "github.com/markbates/goth"
    "github.com/markbates/goth/providers/github"
)

goth.UseProviders(
    github.New(clientID, clientSecret, baseURL+"/-/auth/providers/github/callback", "read:user"),
)

r.Use(xauth.UseAuthContext(authService))

r.Mount("/-/auth", xauth.NewGothHandler(&xauth.GothConfig[User, string]{
    Service: authService,
    SessionStorage: xauth.NewCookieStore(sessionKey, encryptKey),
}))

r.With(xauth.UseAuthRequired[User]()).Get("/me", func(w http.ResponseWriter, r *http.Request) {
    user := xauth.IdentFromContext[User](r.Context())
    chix.JSON(w, r, http.StatusOK, user)
})
```

Key concepts:

- `xauth.UseAuthContext` injects auth info into every request's context (even unauthenticated ones).
- `xauth.UseAuthRequired[T]()` rejects unauthenticated requests.
- `xauth.IdentFromContext[T]` retrieves the resolved user from context.
- `xauth.IDFromContext` retrieves just the user ID.
- `xauth.NewCookieStore` uses encrypted cookies for session storage -- no server-side state required, though it does not support server-side session invalidation by default.
- `xauth.GenerateAuthKey()` and `xauth.GenerateEncryptionKey()` generate secure keys for initial setup.

### Security Middleware

chix includes middleware for `robots.txt` and `security.txt` responses, and restricting routes to private/internal IPs.

```go
r.Use(
    chix.UseRobotsText(&chix.RobotsTextConfig{
        Rules: []chix.RobotsTextRule{
            {UserAgent: "*", Disallow: []string{"/"}},
        },
    }),
    chix.UseSecurityText(chix.SecurityTextConfig{
        ExpiresIn: 182 * 24 * time.Hour,
        Contacts:  []string{"https://example.com/security"},
        KeyLinks:  []string{"https://example.com/pgp-key.txt"},
        Languages: []string{"en"},
    }),
)

if cli.Debug {
    r.With(chix.UsePrivateIP()).Mount("/debug", middleware.Profiler())
}
```

### Graceful Shutdown with `chix.Run`

`chix.Run` manages the lifecycle of an `*http.Server`: it starts the server, listens for `SIGINT`/`SIGTERM`, and coordinates graceful shutdown. The server stops accepting new connections and drains in-flight requests before returning.

```go
func main() {
    ctx := context.Background()
    logger := cli.GetLogger()

    err := chix.Run(ctx, logger, httpServer(logger))
    if err != nil {
        logger.Error("run failed", "error", err)
        os.Exit(1)
    }
}
```

For TLS, use `chix.RunTLS` instead -- same lifecycle management but starts the server with `ListenAndServeTLS`.

#### Lower-Level Server Construction

When you need more control over the `*http.Server` (custom timeouts, TLS config, base context, etc.), use `chix.NewServer` or `chix.NewServerWithoutDefaults`:

- `chix.NewServer(addr, handler)` -- returns an `*http.Server` with sensible defaults (read/write timeouts, etc.) already applied.
- `chix.NewServerWithoutDefaults(addr, handler)` -- returns a bare `*http.Server` with no defaults, for cases where you want full control over every field.

Both return an `*http.Server` that can be passed to `chix.Run` or `chix.RunTLS`.

#### Combining with the Scheduler

When your application needs both an HTTP server and background jobs, use `chix.Run` as a long-running worker inside `scheduler.Run` (see `references/scheduling.md`). The scheduler coordinates shutdown of all components -- cancelling the context propagates to the HTTP server and all jobs.

```go
func main() {
    ctx := context.Background()
    logger := cli.GetLogger()

    err := scheduler.Run(
        ctx,
        scheduler.JobFunc(func(ctx context.Context) error {
            return chix.Run(ctx, logger, httpServer(logger))
        }),
        scheduler.NewCron("sync-data", &syncJob{logger: logger}).
            WithInterval(30*time.Second).
            WithImmediate(true).
            WithLogger(logger),
    )
    if err != nil {
        logger.Error("scheduler exited with error", "error", err)
        os.Exit(1)
    }
}
```

This pattern gives you:

- A single `SIGINT`/`SIGTERM` handler for the entire process (via the scheduler).
- Graceful drain of both HTTP requests and background jobs.
- Structured error propagation -- if any component fails, the scheduler cancels everything and returns the error.

### Complete Server Example

Putting it all together -- a production server with logging, error handling, security headers, static SPA, API routes, and graceful shutdown.

```go
package main

import (
    "context"
    "embed"
    "log/slog"
    "net/http"
    "os"
    "time"

    "github.com/go-chi/chi/v5"
    "github.com/go-chi/chi/v5/middleware"
    "github.com/lrstanley/chix/v2"
    "github.com/lrstanley/clix/v2"
)

type Flags struct {
    HTTP struct {
        Bind string `name:"bind" env:"BIND" default:":8080" help:"The address:port to bind to."`
    } `embed:"" prefix:"http." envprefix:"HTTP_" group:"HTTP server flags"`
}

var (
    cli        = clix.NewWithDefaults[Flags]()
    //go:embed all:public
    frontendFS embed.FS
)

func main() {
    ctx := context.Background()
    logger := cli.GetLogger()

    err := chix.Run(ctx, logger, httpServer(logger))
    if err != nil {
        logger.Error("run failed", "error", err)
        os.Exit(1)
    }
}

func httpServer(logger *slog.Logger) *http.Server {
    r := chi.NewRouter()
    r.Use(
        chix.NewConfig().
            SetLogger(logger).
            SetAPIBasePath("/api").
            Use(),
        chix.UseDebug(cli.Debug),
        chix.UseRealIP(nil),
        chix.UseContextIP(),
        chix.UseRequestID(),
        chix.UseStripSlashes(),
        chix.UseStructuredLogger(chix.DefaultLogConfig()),
        chix.UseHeaders(map[string]string{
            "Content-Security-Policy": "default-src 'self'; img-src * data:; style-src 'self' 'unsafe-inline'; object-src 'none'",
            "X-Frame-Options":         "DENY",
            "X-Content-Type-Options":  "nosniff",
            "Referrer-Policy":         "no-referrer-when-downgrade",
        }),
    )

    r.Route("/api", func(r chi.Router) {
        r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
            chix.JSON(w, r, http.StatusOK, map[string]string{"status": "ok"})
        })
    })

    if cli.Debug {
        r.With(chix.UsePrivateIP()).Mount("/debug", middleware.Profiler())
    }

    r.With(chix.UseHeaders(map[string]string{
        "Cache-Control": "public, max-age=3600",
    })).Mount("/", chix.UseStatic(&chix.StaticConfig{
        FS:     frontendFS,
        Prefix: "/",
        SPA:    true,
        Path:   "public",
    }))

    r.NotFound(func(w http.ResponseWriter, r *http.Request) {
        chix.ErrorWithCode(w, r, http.StatusNotFound)
    })

    return &http.Server{
        Addr:    cli.Flags.HTTP.Bind,
        Handler: r,
    }
}
```
