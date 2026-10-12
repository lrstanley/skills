# HTTP Clients, Transport Wrappers, and Observability

## Foundations: default transport and timeouts

**Always** build transports on top of `http.DefaultTransport` (or a clone from `http.DefaultTransport.Clone()` when you need to adjust TLS, timeouts on the transport, or other dial settings). That transport implements connection pooling, HTTP/2 where applicable, and proxy behavior consistent with the standard library.

**Always** set `http.Client.Timeout` to a non-zero value. Without it, a stuck request can hang forever. Pick a limit that fits your SLA (for example, 15–30 seconds for typical APIs; longer only when uploads or large downloads require it).

```go
client := &http.Client{
    Timeout:   30 * time.Second,
    Transport: http.DefaultTransport,
}
```

**Note:** `httpclog`, `httpcretry`, `httpccache`, and `httpcconc` each expose `NewClient` as well as `NewTransport`. The `Config`-based packages use the same shape for both; `httpcconc` uses `NewClient(maxConcurrent, baseTransport)`. Defaults include a non-zero client timeout where the package sets one.

## Wrapping order when composing multiple utilities

When using more than one of the transports below, wrap them in this order (outermost to innermost):

1. `github.com/lrstanley/x/http/utils/httpcretry`
2. `github.com/lrstanley/x/http/utils/httpclog`
3. `github.com/lrstanley/x/http/utils/httpccache`
4. `github.com/lrstanley/x/http/utils/httpcconc`

**`httpcretry` wraps `httpclog`** so each origin attempt is logged. **`httpcconc`** sits directly on `http.DefaultTransport` (or your customized clone): it limits how many round trips reach the cache and the network stack beneath. **`httpccache`** sits between logging and concurrency so misses and revalidation flow through the semaphore before hitting the pooled transport.

Conceptually:

```text
httpcretry → httpclog → httpccache → httpcconc → http.DefaultTransport
```

---

## `github.com/lrstanley/x/http/utils/httpclog`

Structured request and response logging via `log/slog`, with optional full trace dumps when enabled.

**When to use:**

- You need request/response visibility in production or debugging without ad-hoc `fmt.Printf`.
- You want header allowlists and optional `HTTP_TRACE`-style full dumps.

### Custom log level (`&level`)

`Config.Level` controls the level for successful request/response logs (errors still log at error severity). Use a pointer so the transport can compare against the handler:

```go
httpClient := httpclog.NewClient(&httpclog.Config{
    Level:         new(slog.LevelDebug),
    Logger:        slog.Default(),
    BaseTransport: http.DefaultTransport,
})
```

---

## `github.com/lrstanley/x/http/utils/httpcretry`

Retries failed or retryable responses with exponential backoff, optional `Retry-After` handling, and an optional callback before each retry.

**When to use:**

- Calling flaky HTTP APIs or services that return `429` or `5xx` intermittently.
- You need bounded retries with backoff instead of tight loops.

**When not to use:**

- The server already enforces strict rate limits and retries would make things worse without coordination.

### `RetryCallback` with `httpcretry.LoggerCallback`

Use `RetryCallback` for structured visibility into retry attempts. `LoggerCallback` emits a log line before each retry:

```go
httpClient := httpcretry.NewClient(&httpcretry.Config{
    BaseTransport:   http.DefaultTransport,
    MaxRetries:      3,
    RetryCallback:   httpcretry.LoggerCallback(logger, slog.LevelWarn),
})
```

---

## `github.com/lrstanley/x/http/utils/httpclog` and `github.com/lrstanley/x/http/utils/httpcretry` together

Place **retry outside** logging so each attempt is logged: the retry transport calls the base transport for every try, and the logger wraps the actual network round trip.

```go
httpClient := httpcretry.NewClient(&httpcretry.Config{
    BaseTransport: httpclog.NewTransport(&httpclog.Config{
        Level:         new(slog.LevelDebug),
        Logger:        logger,
        BaseTransport: http.DefaultTransport,
    }),
    MaxRetries:    3,
    RetryCallback: httpcretry.LoggerCallback(logger, slog.LevelWarn),
})
```

---

## `github.com/lrstanley/x/http/utils/httpcconc`

Semaphore-based limit on how many HTTP requests may be in flight at once through a shared `http.Client` (or transport). Additional goroutines block until a slot is free.

**When to use:**

- You must cap parallel calls to an upstream (protect the remote service or your own memory/FD usage).
- Many workers share one client and you need back-pressure instead of unbounded concurrency.

**When not to use:**

- You already limit concurrency at the task/worker level and double-limiting would only add latency.
- You need token-bucket or QPS rate limiting (this package limits simultaneous requests, not requests per second).

```go
// At most 8 concurrent requests through this client; still uses DefaultTransport underneath for pooling.
httpClient := httpcconc.NewClient(8, http.DefaultTransport)
```

The helper uses a 60 second client timeout by default; set `httpClient.Timeout` if you need a different limit.

---

## `github.com/lrstanley/x/http/utils/httpccache`

HTTP cache as a `RoundTripper`: GET/HEAD caching with pluggable storage (memory by default), revalidation, and structured cache decision logging.

**When to use:**

- Repeated GET/HEAD to cacheable endpoints (CDN-like or internal APIs with proper freshness headers).
- You want to reduce load and latency for idempotent reads.

**When not to use:**

- Responses are personalized, sensitive, or non-cacheable; override `ShouldCacheRequest` carefully or do not use the cache.
- You need a shared cache across processes (use a storage backend that supports that, or a dedicated HTTP cache proxy).

---

## Quick Reference

| Topic | Guideline |
| --- | --- |
| Base transport | Build on `http.DefaultTransport` (or `Clone()` when customizing); preserves pooling and standard behavior. |
| Client timeout | Always set `http.Client.Timeout` > 0. |
| Wrap order | `httpcretry` → `httpclog` → `httpccache` → `httpcconc` → `http.DefaultTransport`. |
| Retry vs log | `httpcretry` wraps `httpclog` so each attempt is logged. |
| `httpcretry` visibility | `RetryCallback: httpcretry.LoggerCallback(logger, slog.LevelWarn)` for retry lines. |
| `httpcconc` | Caps concurrent in-flight requests; not a substitute for QPS rate limits. |
| `httpccache` | GET/HEAD caching with configurable storage; validate cacheability for your API. |
