# Benchmarking

Measure hot paths with `go test -bench` and `testing.B`. Benchmarks live in `*_test.go` next to production code.

## Benchmark functions

```go
func BenchmarkAdd(b *testing.B) {
    for b.Loop() {
        Add(100, 200)
    }
}

// Benchmark with subtests
func BenchmarkStringOperations(b *testing.B) {
    benchmarks := []struct {
        name  string
        input string
    }{
        {
            name:  "short",
            input: "hello",
        },
        {
            name:  "medium",
            input: strings.Repeat("hello", 10),
        },
        {
            name:  "long",
            input: strings.Repeat("hello", 100),
        },
    }

    for _, bm := range benchmarks {
        b.Run(bm.name, func(b *testing.B) {
            for b.Loop() {
                _ = strings.ToUpper(bm.input)
            }
        })
    }
}

// Benchmark with setup
func BenchmarkMapOperations(b *testing.B) {
    m := make(map[string]int)
    for i := range 1000 {
        m[fmt.Sprintf("key%d", i)] = i
    }

    // Don't count setup time

    for b.Loop() {
        _ = m["key500"]
    }
}

// Parallel benchmark
func BenchmarkConcurrentAccess(b *testing.B) {
    var counter int64

    b.RunParallel(func(pb *testing.PB) {
        for pb.Next() {
            atomic.AddInt64(&counter, 1)
        }
    })
}

// Memory allocation benchmark
func BenchmarkAllocation(b *testing.B) {
    b.ReportAllocs() // Report allocations

    for b.Loop() {
        s := make([]int, 1000)
        _ = s
    }
}
```

### `go test` flags for benchmarks and tracing

- **`-benchtime`**: How long each benchmark runs (default `1s`). Use a duration (`5s`, `500ms`) or an iteration count (`100x`) for stable or very fast benches.
- **`-benchmem`**: Print per-benchmark allocation stats (bytes/op, allocs/op) alongside ns/op.
- **`-trace`**: Write an execution trace to a file (e.g. `go test -trace trace.out ./...`). Inspect with `go tool trace trace.out` (scheduling, goroutines, blocking).
- **`-cpuprofile` / `-memprofile`**: Capture profiles for `go tool pprof` (often paired with benchmarks or slow tests). See `references/pprof.md` for how to read profiles, heap sample types, and live `/debug/pprof` usage.

```text
go test -bench . -benchmem -benchtime 5s ./...
go test -trace trace.out ./...
go test -bench . -cpuprofile cpu.prof -memprofile mem.prof ./...
```

## benchstat (compare benchmark runs)

[`benchstat`](https://pkg.go.dev/golang.org/x/perf/cmd/benchstat) summarizes `go test -bench` output and compares two or more saved runs so you can see whether a speedup is real or noise.

Install:

```bash
go install golang.org/x/perf/cmd/benchstat@latest
```

Minimal A/B flow: save **before** and **after** output with the **same** flags, machine, and load; use **`-count`** (for example `10`) so each line in the file is one sample:

```bash
go test -run='^$' -bench=BenchmarkParse -benchmem -count=10 ./pkg/... | tee old.txt
# change code
go test -run='^$' -bench=BenchmarkParse -benchmem -count=10 ./pkg/... | tee new.txt
benchstat old.txt new.txt
```

`-run='^$'` runs no tests, only benchmarks. The report shows **vs base** (change from the first file), **p=** (rough significance; low is more trustworthy), and **`~`** when the difference is not distinguishable from noise—do not treat that as a win.

## Quick Reference

| Command | Description |
| --- | --- |
| `go test -bench .` | Run benchmarks |
| `go test -bench . -benchmem` | Print memory allocation stats per benchmark |
| `go test -bench . -benchtime 5s` | Run each benchmark longer (default `1s`; or use `100x` for iteration count) |
| `go test -trace trace.out` | Write execution trace; open with `go tool trace trace.out` |
| `go test -cpuprofile cpu.prof` | CPU profile for pprof |
| `go test -memprofile mem.prof` | Heap profile for pprof |
| `benchstat old.txt new.txt` | Compare saved benchmark outputs (install `golang.org/x/perf/cmd/benchstat`) |
