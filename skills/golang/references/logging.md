# Structured Logging with `slog`

## Why Structured Logging

Structured logs emit key-value pairs instead of freeform strings. Log management systems (Datadog, Grafana Loki, CloudWatch) can index, filter, and aggregate structured fields -- something impossible with `log.Printf` output.

```go
// ✗ Bad -- freeform string, impossible to filter by user_id
log.Printf("ERROR: failed to create user %s: %v", userID, err)

// ✓ Good -- structured key-value pairs, machine-parseable
slog.ErrorContext
    ctx, "user creation failed",
    "user_id", userID,
    "error", err,
)
// JSON output: {"time":"2025-01-15T10:30:00Z","level":"ERROR","msg":"user creation failed","user_id":"u-123","error":"connection refused"}
```

## Handler Setup

When using `github.com/lrstanley/clix/v2`, it will pre-configure a log handler (unless explicitly disabled), which you can reference and pass to downstream functions. It handles pretty printing, JSON, auto-configuring levels, etc:

```go
package main

import "github.com/lrstanley/clix/v2"

// [...]

var cli = clix.NewWithDefaults[Flags]()

func main() {
    logger := cli.GetLogger()

    // [...]

    logger.InfoContext(ctx, "hello, world")
}
```

When clix isn't used:

```go
// Production MUST use JSON -- because plain-text multiline logs (e.g. stack traces) would be split into separate records by log collectors
logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
    Level: slog.LevelInfo,
}))

// Development -- human-readable text
logger := slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{
    Level: slog.LevelDebug,
}))

slog.SetDefault(logger)
```

## Log Levels

```go
slog.DebugContext(ctx, "cache lookup", "key", cacheKey, "hit", false)
slog.InfoContext(ctx, "order created", "order_id", orderID, "total", amount)
slog.WarnContext(ctx, "rate limit approaching", "current_usage", 0.92, "limit", 1000)
slog.ErrorContext(ctx, "payment failed", "order_id", orderID, "error", err)
```

**Rule of thumb**: if you're unsure between Warn and Error, ask "did the operation succeed?" If yes (even with degradation), use Warn. If no, use Error.

## Cost of Logging

Logging is not free. Each log line costs CPU (serialization), I/O (disk/network), and money (log ingestion/storage in your aggregation platform). The cost scales with volume, which is directly controlled by log level.

- **Debug level in production** can generate millions of log lines per minute in a busy service, overwhelming your log pipeline and inflating costs by 10-100x
- **Info level** is the typical production default -- it provides enough visibility without excessive volume
- Debug level SHOULD be disabled in production -- use `slog.LevelInfo` in production and `slog.LevelDebug` only in development or when actively debugging a specific issue

## Logging with Context

MUST use the `*Context` variants to correlate logs with the current trace. When an OpenTelemetry bridge is configured, trace_id and span_id are automatically injected into log records.

```go
// ✗ Bad -- no trace correlation
slog.Error("query failed", "error", err)

// ✓ Good -- trace_id/span_id attached automatically when OTel bridge is active
slog.ErrorContext(ctx, "query failed", "error", err)
```

## Adding Request-Scoped Attributes

Use `slog.With()` to create a child logger that includes attributes on every log line. Middleware can inject request-scoped fields so all downstream logs carry the same context.

```go
func LoggingMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        logger := slog.With(
            "request_id", r.Header.Get("X-Request-ID"),
            "method", r.Method,
            "path", r.URL.Path,
        )
        // Store enriched logger in context for downstream use
        ctx := WithLogger(r.Context(), logger)
        next.ServeHTTP(w, r.WithContext(ctx))
    })
}
```

## Common Logging Mistakes

```go
// ✗ Bad -- errors MUST be either logged OR returned, NEVER both (single handling rule violation)
if err != nil {
    slog.Error("query failed", "error", err)
    return fmt.Errorf("query: %w", err) // error gets logged twice up the chain
}

// ✓ Good -- return with context, log at the top level
if err != nil {
    return fmt.Errorf("querying users: %w", err)
}

// ✗ Bad -- NEVER log PII (emails, SSNs, passwords, tokens)
slog.Info("user logged in", "email", user.Email, "ssn", user.SSN)

// ✓ Good -- log identifiers, not sensitive data
slog.Info("user logged in", "user_id", user.ID)
```
