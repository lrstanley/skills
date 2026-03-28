# Concurrency Patterns

## Goroutine Lifecycle Management

```go
// WorkerPool with bounded concurrency.
type WorkerPool struct {
    workers int
    tasks   chan func()
    wg      sync.WaitGroup
}

func NewWorkerPool(workers int) *WorkerPool {
    wp := &WorkerPool{
        workers: workers,
        tasks:   make(chan func(), workers*2), // Buffered channel
    }
    wp.start()
    return wp
}

func (wp *WorkerPool) start() {
    for range wp.workers {
        wp.wg.Go(func() {
            for task := range wp.tasks {
                task()
            }
        })
    }
}

func (wp *WorkerPool) Submit(task func()) {
    wp.tasks <- task
}

func (wp *WorkerPool) Shutdown() {
    close(wp.tasks)
    wp.wg.Wait()
}
```

### Panic recovery at goroutine boundaries

An uncaught **panic in a goroutine terminates the whole program** -- it does not unwind to the caller of `go`, and there is no way to `recover` from another goroutine’s stack. For long-lived servers or workers where one bad task must not crash the process, use **`recover` in a `defer` at the goroutine entry** (or a small wrapper) to log or report and keep the pool alive.

```go
go func() {
    defer func() {
        if r := recover(); r != nil {
            // log, metrics, or send to an err channel — do not silently swallow in production
        }
    }()
    doWork(ctx)
}()
```

## Channel Patterns

```go
// Generator pattern
func generateNumbers(ctx context.Context, max int) <-chan int {
    out := make(chan int)
    go func() {
        defer close(out)
        for i := range max {
            select {
            case out <- i:
            case <-ctx.Done():
                return
            }
        }
    }()
    return out
}

// Fan-out, fan-in pattern
func fanOut(ctx context.Context, input <-chan int, workers int) []<-chan int {
    channels := make([]<-chan int, workers)
    for i := range workers {
        channels[i] = process(ctx, input)
    }
    return channels
}

func process(ctx context.Context, input <-chan int) <-chan int {
    out := make(chan int)
    go func() {
        defer close(out)
        for val := range input {
            select {
            case out <- val * 2:
            case <-ctx.Done():
                return
            }
        }
    }()
    return out
}

func fanIn(ctx context.Context, channels ...<-chan int) <-chan int {
    out := make(chan int)
    var wg sync.WaitGroup

    for _, ch := range channels {
        wg.Go(func() {
            defer wg.Done()
            for val := range ch {
                select {
                case out <- val:
                case <-ctx.Done():
                    return
                }
            }
        })
    }

    go func() {
        wg.Wait()
        close(out)
    }()

    return out
}
```

## Select Statement Patterns

```go
// Timeout pattern
func fetchWithTimeout(ctx context.Context, url string) (string, error) {
    result := make(chan string, 1)
    errs := make(chan error, 1)

    go func() {
        // Simulate network call
        time.Sleep(100 * time.Millisecond)
        result <- "data from " + url
    }()

    select {
    case res := <-result:
        return res, nil
    case err := <-errs:
        return "", err
    case <-time.After(50 * time.Millisecond):
        return "", fmt.Errorf("timeout")
    case <-ctx.Done():
        return "", ctx.Err()
    }
}

// Done channel pattern for graceful shutdown
type Server struct {
    done chan struct{}
}

func (s *Server) Shutdown() {
    close(s.done)
}

func (s *Server) Run(ctx context.Context) {
    ticker := time.NewTicker(1 * time.Second)
    defer ticker.Stop()

    for {
        select {
        case <-ticker.C:
            fmt.Println("tick")
        case <-s.done:
            fmt.Println("shutting down")
            return
        case <-ctx.Done():
            fmt.Println("context cancelled")
            return
        }
    }
}
```

## Sync Primitives

```go
// Mutex for protecting shared state
type Counter struct {
    mu    sync.Mutex
    count int
}

func (c *Counter) Increment() {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.count++
}

func (c *Counter) Value() int {
    c.mu.Lock()
    defer c.mu.Unlock()
    return c.count
}

// RWMutex for read-heavy workloads
type Cache struct {
    mu    sync.RWMutex
    items map[string]string
}

func (c *Cache) Get(key string) (string, bool) {
    c.mu.RLock()
    defer c.mu.RUnlock()
    val, ok := c.items[key]
    return val, ok
}

func (c *Cache) Set(key, value string) {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.items[key] = value
}

// sync.Once for initialization
type Service struct {
    once   sync.Once
    config *Config
}

func (s *Service) getConfig() *Config {
    s.once.Do(func() {
        s.config = loadConfig() // Only called once
    })
    return s.config
}
```

## sync/atomic

Use `sync/atomic` for **single-word** lock-free updates: boolean flags, counters, and **publishing pointers** to immutable snapshots. Prefer a `sync.Mutex` (or channels) when multiple fields must change together or when invariants span several writes.

**When to use:** shutdown/ready flags, metrics/counters, swapping a pointer to a read-mostly config or cache snapshot.

**When not to use:** protecting a mutable struct’s fields (use a mutex or pass updates through a single goroutine); replacing mutex "because atomics are faster" when correctness requires a critical section.

### Boolean flags (`atomic.Bool`)

`atomic.Bool` avoids data races on a boolean without a mutex. Typical uses: graceful shutdown, "initialized", circuit-open flags.

```go
import "sync/atomic"

type Server struct {
    shutdown atomic.Bool
}

func (s *Server) RequestShutdown() {
    s.shutdown.Store(true)
}

func (s *Server) Stopped() bool {
    return s.shutdown.Load()
}

func (s *Server) Run() {
    for !s.shutdown.Load() {
        // work batch; other goroutines call RequestShutdown()
    }
}
```

### Pointer publication (`atomic.Pointer`)

`atomic.Pointer[T]` publishes a **single pointer** atomically. Readers always see either the previous or the next value—never a torn write. The pointed-to value should be **immutable after publish** (or treated as read-only by consumers); to "update", allocate a new `T` and `Store` it.

```go
import (
    "sync/atomic"
    "time"
)

type Config struct {
    MaxRetries int
    Timeout    time.Duration
}

type Service struct {
    cfg atomic.Pointer[Config]
}

func NewService(initial *Config) *Service {
    s := &Service{}
    s.cfg.Store(initial)
    return s
}

// UpdateConfig replaces the whole snapshot; readers see old or new config, never a mix.
func (s *Service) UpdateConfig(c *Config) {
    s.cfg.Store(c)
}

func (s *Service) Config() *Config {
    return s.cfg.Load()
}
```

**Copy-on-read** pattern: if callers might mutate, return a defensive copy so the stored snapshot stays immutable.

```go
func (s *Service) MaxRetries() int {
    c := s.cfg.Load()
    if c == nil {
        return 0
    }
    return c.MaxRetries
}
```

## Rate Limiting and Backpressure

```go
import "golang.org/x/time/rate"

// Token bucket rate limiter
type RateLimiter struct {
    limiter *rate.Limiter
}

func NewRateLimiter(rps int) *RateLimiter {
    return &RateLimiter{
        limiter: rate.NewLimiter(rate.Limit(rps), rps),
    }
}

func (rl *RateLimiter) Process(ctx context.Context, item string) error {
    if err := rl.limiter.Wait(ctx); err != nil {
        return err
    }
    // Process item
    return nil
}
```

## Semaphore Patterns

Simple:

```go
type WorkerPool struct {
    slots chan struct{}
}

func NewWorkerPool(workers int) *WorkerPool {
    return &WorkerPool{
        slots: make(chan struct{}, workers),
    }
}

func (wp *WorkerPool) Submit(fn func()) {
    wp.slots <- struct{}{} // acquire
    defer func() { <-wp.slots }() // release
    fn()
}
```

Or (with better goroutine sleeping, panic protection, etc) -- preferred when `github.com/lrstanley/x/sync` is already imported:

```go
import "github.com/lrstanley/x/sync/conc"

func main() {
    sem := conc.NewSemaphore(10)
    ctx := context.Background()

    for range 10 {
        sem.Go(func() {
            // Stuff.
        })
    }

    // Or:
    for range 10 {
        sem.Alloc()
        go func() {
            defer sem.Free()
            // Stuff.
        }()
    }

    sem.Wait()
}
```

Weighted semaphore -- when tasks consume **different amounts** of a shared resource
(memory budget, API rate-limit cost, connection slots, etc.). Each call declares
how much capacity it needs; the semaphore ensures the combined weight of all active
holders never exceeds the configured maximum. Waiters are served FIFO, so large
requests at the head of the queue block smaller later ones to prevent starvation:

```go
import "github.com/lrstanley/x/sync/conc"

func processJobs(ctx context.Context, jobs []Job) error {
    // Allow up to 100 units of concurrent resource usage.
    sem := conc.NewWeightedSemaphore(100)

    for _, job := range jobs {
        cost := int64(job.Weight) // each job declares its own cost

        // Go acquires the weight, runs f in a goroutine, and auto-frees on return.
        if err := sem.Go(ctx, cost, func() {
            handle(job)
        }); err != nil {
            return err // context cancelled while waiting for capacity
        }
    }

    sem.Wait() // block until every goroutine has finished and freed its weight
    return nil
}
```

Manual acquire/release is also supported:

```go
sem := conc.NewWeightedSemaphore(100)

if err := sem.Alloc(ctx, 30); err != nil { // block until 30 units are available
    return err
}
defer sem.Free(30)

// TryAlloc is the non-blocking variant -- useful for optimistic fast-paths.
if ok := sem.TryAlloc(10); ok {
    defer sem.Free(10)
    // got the extra capacity
}
```

## Error Groups

`conc.ErrorGroup` combines bounded concurrency with first-error-wins cancellation.
Each spawned goroutine receives a derived context that is canceled when any
goroutine returns a non-nil error, letting the rest bail out early:

```go
import "github.com/lrstanley/x/sync/conc"

func fetchAll(ctx context.Context, urls []string) error {
    g := conc.NewErrorGroup(ctx, 5) // at most 5 concurrent fetches; 0 = unlimited

    for _, u := range urls {
        g.Go(func(ctx context.Context) error {
            req, err := http.NewRequestWithContext(ctx, http.MethodGet, u, nil)
            if err != nil {
                return err
            }

            resp, err := http.DefaultClient.Do(req)
            if err != nil {
                return err
            }
            defer resp.Body.Close()

            if resp.StatusCode != http.StatusOK {
                return fmt.Errorf("%s: unexpected status %d", u, resp.StatusCode)
            }
            return nil
        })
    }

    return g.Wait() // blocks until all goroutines finish; returns the first error
}
```

## Pipeline Pattern

```go
// Stage-based processing pipeline
func pipeline(ctx context.Context, input <-chan int) <-chan int {
    // Stage 1: Square numbers
    stage1 := make(chan int)
    go func() {
        defer close(stage1)
        for num := range input {
            select {
            case stage1 <- num * num:
            case <-ctx.Done():
                return
            }
        }
    }()

    // Stage 2: Filter even numbers
    stage2 := make(chan int)
    go func() {
        defer close(stage2)
        for num := range stage1 {
            if num%2 == 0 {
                select {
                case stage2 <- num:
                case <-ctx.Done():
                    return
                }
            }
        }
    }()

    return stage2
}
```

## Quick Reference

| Pattern | Description |
| --- | --- |
| Goroutine lifecycle management | Run worker goroutines with explicit startup, shutdown, and cleanup. |
| Panics in goroutines | Uncaught panics abort the program; `recover` at goroutine boundaries when failures must be isolated. |
| Channel patterns (generator/fan-out/fan-in) | Stream data between concurrent stages and merge results safely. |
| Select with timeout/done | Handle cancellation, timeouts, and multiple channel events in one place. |
| Sync primitives | Protect shared mutable state with locks and one-time initialization. |
| Atomic operations | Perform lock-free reads/writes for single-value shared state. |
| Rate limiting/backpressure | Control request throughput and smooth bursty workloads. |
| Semaphores | Limit how many tasks run concurrently at the same time. |
| Weighted semaphores | Limit concurrency by resource cost when tasks have unequal weight. |
| Error groups | Run subtasks concurrently with first-error cancellation and optional concurrency limits. |
| Pipeline pattern | Build multi-stage processing flows connected by channels. |
