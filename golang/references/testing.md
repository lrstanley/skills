# Testing

For benchmarks, `go test -bench`, profiling, and execution traces, see `references/benchmarking.md`.

## Table-Driven Tests

```go
func Add(a, b int) int {
    return a + b
}

func TestAdd(t *testing.T) {
    tests := []struct {
        name     string
        a        int
        b        int
        expected int
    }{
        {
            name:     "positive numbers",
            a:        2,
            b:        3,
            expected: 5,
        },
        {
            name:     "negative numbers",
            a:        -2,
            b:        -3,
            expected: -5,
        },
        {
            name:     "mixed signs",
            a:        -2,
            b:        3,
            expected: 1,
        },
        {
            name:     "zeros",
            a:        0,
            b:        0,
            expected: 0,
        },
        {
            name:     "large numbers",
            a:        1000000,
            b:        2000000,
            expected: 3000000,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            result := Add(tt.a, tt.b)
            if result != tt.expected {
                t.Errorf("Add(%d, %d) = %d; want %d", tt.a, tt.b, result, tt.expected)
            }
        })
    }
}
```

## Subtests and Parallel Execution

```go
func TestParallel(t *testing.T) {
    tests := []struct {
        name  string
        input string
        want  string
    }{
        {
            name:  "lowercase",
            input: "hello",
            want:  "HELLO",
        },
        {
            name:  "uppercase",
            input: "WORLD",
            want:  "WORLD",
        },
        {
            name:  "mixed",
            input: "HeLLo",
            want:  "HELLO",
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            t.Parallel()

            result := strings.ToUpper(tt.input)
            if result != tt.want {
                t.Errorf("got %q, want %q", result, tt.want)
            }
        })
    }
}
```

## Test Helpers and Setup/Teardown

```go
func TestWithSetup(t *testing.T) {
    // Setup
    db := setupTestDB(t)
    defer cleanupTestDB(t, db)

    tests := []struct {
        name string
        user User
    }{
        {"valid user", User{Name: "John", Email: "john@example.com"}},
        {"empty name", User{Name: "", Email: "test@example.com"}},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := db.SaveUser(tt.user)
            if err != nil {
                t.Fatalf("SaveUser failed: %v", err)
            }
        })
    }
}

// Helper function (doesn't show in stack trace)
func setupTestDB(t *testing.T) *DB {
    t.Helper()

    db, err := NewDB(":memory:")
    if err != nil {
        t.Fatalf("failed to create test DB: %v", err)
    }
    return db
}

func cleanupTestDB(t *testing.T, db *DB) {
    t.Helper()

    if err := db.Close(); err != nil {
        t.Errorf("failed to close DB: %v", err)
    }
}
```

## Mocking with Interfaces

```go
// Interface to mock
type EmailSender interface {
    Send(to, subject, body string) error
}

// Mock implementation
type MockEmailSender struct {
    SentEmails []Email
    ShouldFail bool
}

type Email struct {
    To, Subject, Body string
}

func (m *MockEmailSender) Send(to, subject, body string) error {
    if m.ShouldFail {
        return fmt.Errorf("failed to send email")
    }
    m.SentEmails = append(m.SentEmails, Email{to, subject, body})
    return nil
}

// Test using mock
func TestUserService_Register(t *testing.T) {
    mockSender := &MockEmailSender{}
    service := NewUserService(mockSender)

    err := service.Register("user@example.com")
    if err != nil {
        t.Fatalf("Register failed: %v", err)
    }

    if len(mockSender.SentEmails) != 1 {
        t.Errorf("expected 1 email sent, got %d", len(mockSender.SentEmails))
    }

    email := mockSender.SentEmails[0]
    if email.To != "user@example.com" {
        t.Errorf("expected email to user@example.com, got %s", email.To)
    }
}
```

## Fuzzing (Go 1.18+)

```go
func FuzzReverse(f *testing.F) {
    // Seed corpus
    testcases := []string{"hello", "world", "123", ""}
    for _, tc := range testcases {
        f.Add(tc)
    }

    f.Fuzz(func(t *testing.T, input string) {
        reversed := Reverse(input)
        doubleReversed := Reverse(reversed)

        if input != doubleReversed {
            t.Errorf("Reverse(Reverse(%q)) = %q, want %q", input, doubleReversed, input)
        }
    })
}

// Fuzz with multiple parameters
func FuzzAdd(f *testing.F) {
    f.Add(1, 2)
    f.Add(0, 0)
    f.Add(-1, 1)

    f.Fuzz(func(t *testing.T, a, b int) {
        result := Add(a, b)

        // Properties that should always hold
        if result < a && b >= 0 {
            t.Errorf("Add(%d, %d) = %d; result should be >= a when b >= 0", a, b, result)
        }
    })
}
```

## Test Coverage

```go
// Run tests with coverage:
// go test -cover
// go test -coverprofile=coverage.out
// go tool cover -html=coverage.out

func TestCalculate(t *testing.T) {
    tests := []struct {
        name     string
        input    int
        expected int
    }{
        {
            name:     "zero",
            input:    0,
            expected: 0,
        },
        {
            name:     "positive",
            input:    5,
            expected: 25,
        },
        {
            name:     "negative",
            input:    -3,
            expected: 9,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            result := Calculate(tt.input)
            if result != tt.expected {
                t.Errorf("Calculate(%d) = %d; want %d", tt.input, result, tt.expected)
            }
        })
    }
}
```

## Race Detector

```go
// Run with: go test -race

func TestConcurrentAccess(t *testing.T) {
    var counter int
    var wg sync.WaitGroup

    // This will fail with -race if not synchronized
    for range 10 {
        wg.Go(func() {
            counter++ // Data race!
        })
    }

    wg.Wait()
}

// Fixed version with mutex
func TestConcurrentAccessSafe(t *testing.T) {
    var counter int
    var mu sync.Mutex
    var wg sync.WaitGroup

    for range 10 {
        wg.Go(func() {
            mu.Lock()
            defer mu.Unlock()
            counter++
        })
    }

    wg.Wait()

    if counter != 10 {
        t.Errorf("expected 10, got %d", counter)
    }
}
```

## `testing/synctest` (Go 1.25+)

Package [`testing/synctest`](https://pkg.go.dev/testing/synctest) runs tests in an isolated **bubble**: goroutines started inside the bubble belong to it, `time` uses a **fake clock** per bubble (initial time is midnight UTC 2000-01-01), and time advances only when every goroutine in the bubble is **durably blocked** (e.g. channel ops on bubble channels, `time.Sleep`, `sync.WaitGroup.Wait` after `Add` in the bubble). Use it to test concurrent and timing-dependent code without real sleeps or wall-clock flakiness.

**`synctest.Wait()`** blocks until every other goroutine in the bubble is durably blocked. Use it to assert ordering before the fake clock steps forward.

**`synctest.Sleep(d)`** (Go 1.27+) is `time.Sleep(d)` followed by `synctest.Wait()`. Prefer it in the test itself when the system under test also sleeps for the same duration: `time.Sleep` alone does not say which goroutine runs first after the clock advances, so the test can observe a still-unsettled system. `Sleep` waits until other bubble goroutines are durably blocked again.

**Not durably blocking** (can stall the bubble or behave differently): mutex/RWMutex, I/O and network, arbitrary system calls. Prefer fakes (`net.Pipe`, or `httptest.NewTestServer` below) instead of loopback sockets so goroutines are not stuck on I/O outside the bubble model.

Inside the callback, do not call `t.Run`, `t.Parallel`, or `t.Deadline`. Do not nest `synctest.Test`.

```go
func TestTime(t *testing.T) {
    synctest.Test(t, func(t *testing.T) {
        start := time.Now() // always midnight UTC 2000-01-01
        go func() {
            time.Sleep(1 * time.Second)
            t.Log(time.Since(start)) // always logs "1s"
        }()
        synctest.Sleep(2 * time.Second) // Sleep + Wait; the goroutine above has settled
        t.Log(time.Since(start))        // always logs "2s"
    })
}
```

```go
func TestContextWithTimeout(t *testing.T) {
    synctest.Test(t, func(t *testing.T) {
        ctx, cancel := context.WithTimeout(t.Context(), 5*time.Second)
        defer cancel()

        synctest.Sleep(5*time.Second - time.Nanosecond)
        if err := ctx.Err(); err != nil {
            t.Fatalf("before timeout: ctx.Err() = %v, want nil", err)
        }

        synctest.Sleep(time.Nanosecond)
        if err := ctx.Err(); err != context.DeadlineExceeded {
            t.Fatalf("after timeout: ctx.Err() = %v, want DeadlineExceeded", err)
        }
    })
}
```

## `httptest.NewTestServer`

[`httptest.NewTestServer`](https://pkg.go.dev/net/http/httptest#NewTestServer) (Go 1.27+) creates a test server on an **in-memory fake network**. Use it for handler tests instead of `httptest.NewServer` (loopback). It registers `t.Cleanup` to shut the server down, fails the test if the handler panics (other than `http.ErrAbortHandler`), and returns a client that sends **all** requests to the server regardless of URL host.

The in-memory network is suitable for `testing/synctest` bubbles. Loopback `NewServer` / `Start` is not: goroutines blocked on real network I/O are not durably blocked.

```go
func TestHealth(t *testing.T) {
    handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Content-Type", "application/json")
        io.WriteString(w, `{"status":"ok"}`)
    })

    srv := httptest.NewTestServer(t, handler)
    resp, err := srv.Client().Get("http://example.com/health")
    if err != nil {
        t.Fatal(err)
    }
    defer resp.Body.Close()

    if resp.StatusCode != http.StatusOK {
        t.Fatalf("status = %d, want 200", resp.StatusCode)
    }
}
```

Call `srv.Start()` or `srv.StartTLS()` only when a real loopback listener is required (for example, testing with `http.DefaultClient` and `srv.URL`). Most tests should stay on the in-memory network and use `srv.Client()`.

If the handler is nil, the server answers every request with 500; it does not use `http.DefaultServeMux`.

## Integration Tests

```go
// integration_test.go
//go:build integration

package myapp

import (
    "net/http/httptest"
    "testing"
)

func TestIntegration(t *testing.T) {
    if testing.Short() {
        t.Skip("skipping integration test in short mode")
    }

    srv := httptest.NewTestServer(t, appHandler())
    resp, err := srv.Client().Get("http://example.com/health")
    if err != nil {
        t.Fatalf("health check failed: %v", err)
    }
    defer resp.Body.Close()

    if resp.StatusCode != http.StatusOK {
        t.Errorf("expected status 200, got %d", resp.StatusCode)
    }
}

// Run: go test -tags=integration
// Run short tests only: go test -short
```

## Testable Examples

```go
// Example tests that appear in godoc
func ExampleAdd() {
    result := Add(2, 3)
    fmt.Println(result)
    // Output: 5
}

func ExampleAdd_negative() {
    result := Add(-2, -3)
    fmt.Println(result)
    // Output: -5
}

// Unordered output
func ExampleKeys() {
    m := map[string]int{"a": 1, "b": 2, "c": 3}
    keys := Keys(m)
    for _, k := range keys {
        fmt.Println(k)
    }
    // Unordered output:
    // a
    // b
    // c
}
```

## Quick Reference

| Command | Description |
| --- | --- |
| `go test` | Run tests |
| `go test -v` | Verbose output |
| `go test -run TestName` | Run specific test |
| `go test -cover` | Show coverage |
| `go test -race` | Run race detector |
| `go test -short` | Skip long tests |
| `go test -fuzz FuzzName` | Run fuzzing |
| `go test -v -race -count 10 -cpu 1,4 -timeout 30s` | Miscellaneous testing flags |

Use `synctest.Test` + `synctest.Sleep` for fake-clock concurrency tests. Use `httptest.NewTestServer` for in-memory HTTP (including inside a synctest bubble).
