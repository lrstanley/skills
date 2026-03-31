# Scheduler & Background Jobs

## Overview

`github.com/lrstanley/x/sync/scheduler` manages background jobs for long-running backend/daemon applications. It supports interval-based jobs, crontab-style schedules, and always-on workers. The scheduler listens for `SIGINT`/`SIGTERM` and coordinates graceful shutdown of all jobs.

Pairs naturally with `clix` (see `references/cli-tools.md`) but has no hard dependency on it -- any `context.Context` and `*slog.Logger` work.

## When to Use

- Backend daemons that need periodic tasks (data sync, cache warming, cleanup) alongside an HTTP server or other long-running process.
- Applications that need crontab-style scheduling without an external cron system.
- Services with background workers that must shut down gracefully on signals.

## When Not to Use

- Short-lived CLI commands that run once and exit.
- Cases where an external job scheduler (Kubernetes CronJob, systemd timers) is more appropriate.

## Job Types

The scheduler supports three patterns, all passed as variadic arguments to `scheduler.Run`:

| Pattern | Creation | Invocation |
| --- | --- | --- |
| Interval-based cron | `scheduler.NewCron(name, job).WithInterval(d)` | Repeats every `d` |
| Crontab-style cron | `scheduler.NewCron(name, job).WithSchedule("0 * * * *")` | Standard 5-field crontab |
| Long-running worker | `scheduler.JobFunc(fn)` passed directly (not wrapped in `NewCron`) | Runs once, blocks until ctx cancellation |

## Backend Daemon Example

A typical backend daemon that runs periodic sync jobs and a background worker alongside the main application.

```go
var cli = clix.NewWithDefaults[Flags]()

func main() {
    logger := cli.GetLogger()
    ctx := context.TODO()

    err := scheduler.Run(
        ctx,
        // Interval-based job using the scheduler.Job interface.
        scheduler.NewCron("sync-data", &syncJob{logger: logger}).
            WithInterval(30*time.Second).
            WithImmediate(true).
            WithExitOnError(true).
            WithLogger(logger),

        // Crontab-style schedule using scheduler.JobFunc wrapper.
        scheduler.NewCron("hourly-cleanup", scheduler.JobFunc(cleanup)).
            WithSchedule("0 * * * *"),

        // Long-running background worker (no interval, runs once).
        scheduler.JobFunc(backgroundWorker),
    )
    if err != nil {
        logger.Error("scheduler exited with error", "error", err)
        os.Exit(1)
    }
}
```

## Implementing the `Job` Interface

For jobs that need injected dependencies, implement the `scheduler.Job` interface with an `Invoke(ctx context.Context) error` method.

```go
type syncJob struct {
    logger *slog.Logger
}

func (s *syncJob) Invoke(ctx context.Context) error {
    s.logger.InfoContext(ctx, "syncing data from upstream")
    // ... do work ...
    return nil
}
```

## Using `JobFunc` for Simple Jobs

For stateless jobs, wrap a plain function with `scheduler.JobFunc`.

```go
func cleanup(ctx context.Context) error {
    slog.InfoContext(ctx, "running hourly cleanup")
    return nil
}
```

## Long-Running Workers

Pass a `scheduler.JobFunc` directly to `scheduler.Run` (without wrapping in `NewCron`) for a job that runs continuously until the context is cancelled. The scheduler treats it as a background worker rather than a periodic task.

```go
func backgroundWorker(ctx context.Context) error {
    for {
        select {
        case <-ctx.Done():
            return ctx.Err()
        case <-time.After(10 * time.Second):
            slog.InfoContext(ctx, "worker tick")
        }
    }
}
```

## Cron Configuration Options

`NewCron` returns a builder with some of the following chainable methods:

| Method | Description |
| --- | --- |
| `WithInterval(d)` | Run every `d` duration |
| `WithSchedule(expr)` | Standard 5-field crontab expression |
| `WithImmediate(true)` | Run the job immediately on startup, then at the interval |
| `WithExitOnError(true)` | If the job returns an error, stop all jobs and exit `scheduler.Run` |
| `WithLogger(logger)` | Attach a `*slog.Logger` for the cron wrapper to log lifecycle events |

## Signal Handling

`scheduler.Run` blocks until one of:

- All jobs complete (or a long-running worker returns).
- A `SIGINT` or `SIGTERM` is received -- the context passed to each job is cancelled, giving jobs a chance to clean up.
- A job with `WithExitOnError(true)` returns an error -- all other jobs are cancelled and the error is returned from `scheduler.Run`.
