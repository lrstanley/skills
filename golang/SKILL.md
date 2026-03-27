---
# some skills adapted from & credit to: https://github.com/samber/cc-skills-golang
name: golang
description: >-
  Implements idiomatic Go with concurrency, REST APIs, CLI tools, and performance optimization.
  Use when building Go applications, designing interfaces, writing tests, profiling, or working
  with goroutines, HTTP servers/clients, error handling, tracing, or structured logging.
license: MIT
metadata:
  author: https://github.com/lrstanley
  version: "1.0.0"
  domain: language
  triggers: Go, Golang, goroutines, channels, REST, microservices, generics, interfaces, CLI, TUI, ORM, database, pprof, benchmarks, testing, HTTP client, tracing, OpenTelemetry, OTEL, error handling, context, logging, documentation, godoc, clix, chix, caching
  role: specialist
  scope: implementation
  output-format: code
---

# Golang

Senior Go developer with deep expertise in Go 1.26+, concurrent programming, and
cloud-native microservices. Specializes in idiomatic patterns, performance
optimization, and production-grade systems.

## Core Workflow

1. **Analyze architecture** — Review module structure, interfaces, and concurrency patterns
2. **Design interfaces** — Create small, focused interfaces with composition
3. **Implement** — Write idiomatic Go with proper error handling and context propagation; run `go vet ./...` before proceeding
4. **Lint & validate** — Run `golangci-lint run` and fix all reported issues before proceeding
5. **Optimize** — Eliminate allocations
6. **Test** — Table-driven tests with `-race` flag, fuzzing; confirm race detector passes before committing

## Reference Guide

Load detailed guidance based on context:

| Topic | Reference | Load When |
| --- | --- | --- |
| Concurrency | `references/concurrency.md` | Goroutines, channels, select, sync primitives |
| Context | `references/context.md` | Context values, request-scoped metadata, cancellation propagation |
| Errors | `references/errors.md` | Error wrapping, sentinel errors, `errors.Is`/`As`, custom error types |
| Interfaces | `references/interfaces.md` | Interface design, io.Reader/Writer, composition |
| Generics | `references/generics.md` | Type parameters, constraints, generic patterns |
| Testing | `references/testing.md` | Table-driven tests, subtests, mocks, fuzzing, coverage |
| Benchmarking | `references/benchmarking.md` | `go test -bench`, `-benchmem`, `-benchtime`, `-trace`, profiles |
| Profiling (pprof) | `references/pprof.md` | CPU/heap profiles, `go tool pprof`, contention, leaks |
| Logging | `references/logging.md` | Structured logging, JSON logging |
| Tracing | `references/tracing.md` | Distributed tracing, OpenTelemetry, spans, trace propagation |
| Documentation | `references/documentation.md` | Code comments, godoc conventions, doc comment style |
| Project Structure | `references/project-structure.md` | Module layout, internal packages, go.mod |
| CLI Tools | `references/cli-tools.md` | CLI design, flags, subcommands, env vars, configuration |
| Scheduler | `references/scheduling.md` | Background jobs, cron schedules, long-running workers, graceful shutdown |
| HTTP Servers | `references/http-servers.md` | HTTP routing, middleware, logging, error handling, API design |
| HTTP Clients | `references/http-clients.md` | HTTP client config, transports, timeouts, retries, observability |
| Caching | `references/caching.md` | In-memory caching, FIFO, LRU, TTL |

## Core Pattern Example

Goroutine with proper context cancellation and error propagation:

```go
// worker runs until ctx is cancelled or an error occurs. Errors are returned via
// the errs channel; the caller must drain it.
func worker(ctx context.Context, jobs <-chan Job, errs chan<- error) {
    for {
        select {
        case <-ctx.Done():
            errs <- fmt.Errorf("worker cancelled: %w", ctx.Err())
            return
        case job, ok := <-jobs:
            if !ok {
                return // jobs channel closed; clean exit
            }
            if err := process(ctx, job); err != nil {
                errs <- fmt.Errorf("process job %v: %w", job.ID, err)
                return
            }
        }
    }
}

func runPipeline(ctx context.Context, jobs []Job) error {
    ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
    defer cancel()

    jobs := make(chan Job, len(jobs))
    errs := make(chan error, 1)

    go worker(ctx, jobs, errs)

    for _, j := range jobs {
        jobs <- j
    }
    close(jobs)

    select {
    case err := <-errs:
        return err
    case <-ctx.Done():
        return fmt.Errorf("pipeline timed out: %w", ctx.Err())
    }
}
```

Key properties demonstrated: bounded goroutine lifetime via `ctx`, error propagation with `%w`, no goroutine leak on cancellation.

## Constraints

### MUST DO

- Use gofumpt (when available, otherwise gofmt) and golangci-lint on all code
- Add context.Context to all blocking operations
- Handle all errors explicitly (no naked returns)
- Write table-driven tests with subtests
- Document all exported functions, types, and packages
- Propagate errors with `fmt.Errorf("%w", err)`, `errors.Join`
- Run race detector on tests (`-race` flag)

### MUST NOT DO

- Ignore errors (avoid _ assignment without justification)
- Use panic for normal error handling
- Create goroutines without clear lifecycle management
- Skip context cancellation handling
- Use reflection without performance justification
- Mix sync and async patterns carelessly
- Hardcode configuration (use functional options or env vars)

## Output Templates

When implementing Go features, provide:

1. Interface definitions (contracts first)
2. Implementation files with proper package structure
3. Test file with table-driven tests
4. Brief explanation of concurrency patterns used

## Knowledge Reference

Go 1.26+, goroutines, channels, select, sync package, generics, type parameters,
constraints, io.Reader/Writer, context values, context cancellation, error wrapping,
errors.Is/As, sentinel errors, pprof profiling, benchmarks, table-driven tests,
fuzzing, go.mod, internal packages, functional options, errors.Join, CLI flag & env
var parsing, HTTP routing, middleware, HTTP clients, transport wrappers, retries,
structured logging, OpenTelemetry tracing, godoc conventions, API design.
