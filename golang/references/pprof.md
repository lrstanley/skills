# pprof with Go

[`go tool pprof`](https://pkg.go.dev/cmd/pprof) inspects CPU, heap, and other profiles from Go programs. Use it to find hot functions, allocation churn, contention, and leaks.

## Which profile answers which question?

| Kind | How you get it | Use when |
| --- | --- | --- |
| **CPU** | `go test -cpuprofile`, or `/debug/pprof/profile?seconds=N` | High CPU, slow code paths |
| **Heap (allocations)** | `go test -memprofile`, or `/debug/pprof/heap` | GC pressure, allocation hot spots |
| **Goroutine** | `/debug/pprof/goroutine` | Leaks, piles of blocked goroutines |
| **Mutex** | `/debug/pprof/mutex` (must enable sampling first) | Lock contention |
| **Block** | `/debug/pprof/block` (must enable sampling first) | Waits on channels, locks, sync |
| **Threadcreate** | `/debug/pprof/threadcreate` | Unexpected OS thread churn |

CPU sampling shows **on-CPU** time. It does not explain time blocked in I/O or sleeping—use **block**, **goroutine**, or **execution trace** (`go tool trace`) for that.

## Heap metrics: what to open in pprof

Heap profiles can show different **sample types**. Pick the symptom:

| Sample type | Question it answers |
| --- | --- |
| **`alloc_objects`** | Where do we allocate most *often*? (GC churn) |
| **`alloc_space`** | Where do we allocate most *bytes*? (volume) |
| **`inuse_space`** | What is *live* on the heap right now? (leaks, retained memory) |
| **`inuse_objects`** | How many live *objects* (many small leaks)? |

- **`alloc_*`** is cumulative since process start (includes freed objects).
- **`inuse_*`** is a point-in-time snapshot of live data.

**Rule of thumb:** start with **`alloc_objects`** for GC-heavy code; use **`inuse_space`** when memory grows without bound and you compare two snapshots.

## Capture from benchmarks

No HTTP server required:

```bash
go test -run='^$' -bench=BenchmarkParse -cpuprofile=cpu.prof ./pkg/parser
go test -run='^$' -bench=BenchmarkParse -memprofile=mem.prof ./pkg/parser
```

Both at once adds a bit of overhead; CPU profiling can slightly skew memory-heavy benches:

```bash
go test -run='^$' -bench=BenchmarkParse -cpuprofile=cpu.prof -memprofile=mem.prof ./pkg/parser
```

Open:

```bash
go tool pprof cpu.prof
go tool pprof mem.prof
```

For heap, default is often `inuse_*`; use `-alloc_objects` when you care about allocation counts:

```bash
go tool pprof -alloc_objects mem.prof
```

## Capture from a running service

Import the pprof HTTP handlers (typically `import _ "net/http/pprof"` on your debug or admin server). Secure the endpoint in production (auth, bind localhost, or separate network).

```bash
go tool pprof http://localhost:6060/debug/pprof/profile?seconds=30
go tool pprof -alloc_objects http://localhost:6060/debug/pprof/heap
go tool pprof http://localhost:6060/debug/pprof/goroutine
go tool pprof http://localhost:6060/debug/pprof/mutex
go tool pprof http://localhost:6060/debug/pprof/block
```

Save without interactive UI:

```bash
curl -o heap.prof http://localhost:6060/debug/pprof/heap
```

Human-readable goroutine dump (no pprof):

```bash
curl 'http://localhost:6060/debug/pprof/goroutine?debug=2'
```

## Enable mutex and block profiles

Mutex and block profiles are **off by default**. Turn them on during investigation, then **turn off** when done.

```go
import "runtime"

// Mutex: record a fraction of contention events (e.g. 1 in 5).
runtime.SetMutexProfileFraction(5)

// Block: record blocking above a threshold in nanoseconds (1 = all).
runtime.SetBlockProfileRate(1)
```

Disable:

```go
runtime.SetMutexProfileFraction(0)
runtime.SetBlockProfileRate(0)
```

## Capture from code

```go
import (
	"os"
	"runtime/pprof"
)

func writeCPU(path string) error {
	f, err := os.Create(path)
	if err != nil {
		return err
	}
	defer f.Close()
	if err := pprof.StartCPUProfile(f); err != nil {
		return err
	}
	defer pprof.StopCPUProfile()
	// ... work ...
	return nil
}

func writeHeap(path string) error {
	f, err := os.Create(path)
	if err != nil {
		return err
	}
	defer f.Close()
	return pprof.WriteHeapProfile(f)
}
```

## Reading `top`: flat vs cumulative

At the `(pprof)` prompt, **`top`** is the first command.

| Column | Meaning |
| --- | --- |
| **flat** | Time (or allocations) in the function **itself** |
| **flat%** | Share of total |
| **cum** | In this function **plus everything it calls** |
| **cum%** | Cumulative share |

- **High flat** → the function body is expensive.
- **Low flat, high cum** → the function is cheap but calls expensive work; use **`list`**, **`peek`**, or **`top -cum`** to find callees.

When **`runtime.mallocgc`**, **`runtime.memmove`**, or **`runtime.scanobject`** dominate top, **do not** stop there. Switch to a **heap** profile (`-alloc_objects`) or use **`top -cum`** to see which **application** code triggered the runtime.

## Interactive commands (essentials)

Open interactive mode:

```bash
go tool pprof cpu.prof
# or
go tool pprof http://localhost:6060/debug/pprof/profile?seconds=10
```

Inside `(pprof)`:

```text
top                  # hottest by flat time (default)
top -cum             # hottest by cumulative time
top 5                # only top 5
list mypkg.FuncName  # source lines with costs
peek json.Marshal    # one-hop callers and callees
tree                 # hierarchical tree
traces               # raw stacks (spot unexpected paths)
```

**One-shot from the shell** (no interactive session):

```bash
go tool pprof -top cpu.prof
go tool pprof -cum -top -nodecount=20 cpu.prof
go tool pprof -list=mypkg.Parse cpu.prof
go tool pprof -peek=serializeResponse cpu.prof
go tool pprof -tree cpu.prof
```

**Graphs** (needs `graphviz` for some formats):

```bash
go tool pprof -svg cpu.prof > cpu.svg
go tool pprof -http=:8080 cpu.prof
```

The **`-http`** UI gives flamegraph, graph, source, and disassembly—good when the CLI feels cramped.

## Web UI shortcut

```bash
go tool pprof -http=:8080 cpu.prof
go tool pprof -http=:8080 -alloc_objects mem.prof
```

Compare two heap snapshots in the browser:

```bash
go tool pprof -http=:8080 -base heap-before.prof heap-after.prof
```

## Comparing profiles (`-base`)

Subtract a **baseline** profile from a **later** one. Values become **deltas**—ideal for leaks and regressions.

```bash
go tool pprof -base heap-baseline.prof heap-after.prof
```

Use **`top`**, **`list`**, etc. as usual. For heap diffs, take snapshots **minutes apart** under the same load pattern.

CPU before/after code changes: compare visually or use `-base`:

```bash
go tool pprof -top -base cpu-before.prof cpu-after.prof
```

For statistical comparison of **benchmark numbers** (ns/op), prefer **benchstat**, not profile diffs.

## Filtering noise (CLI flags)

Narrow large profiles:

```bash
go tool pprof -focus=mypkg -top cpu.prof
go tool pprof -ignore=runtime -top cpu.prof
go tool pprof -cum -top -nodecount=15 -focus=handler cpu.prof
```

**`focus`** keeps paths through a matching symbol. **`ignore`** removes matching symbols from the graph (cost rolls up to callers). Reset interactive filters with **`reset`** inside the shell.

## Heap: switch sample type without reloading

In interactive mode:

```text
sample_index=alloc_objects
top
sample_index=inuse_space
top
```

Or from the CLI:

```bash
go tool pprof -alloc_objects -top mem.prof
go tool pprof -alloc_space -top mem.prof
go tool pprof -inuse_space -top mem.prof
```

## Common shapes (what they mean)

| What you see | Likely meaning | Next step |
| --- | --- | --- |
| High **flat** in app code | Hot loop or heavy work in that function | **list**, optimize algorithm, reduce work |
| Low **flat**, high **cum** in app code | Thin wrapper calling slow code | **peek** / **list** callees |
| **`runtime.mallocgc`** high in CPU | Allocation + GC cost dominates | **-alloc_objects** heap profile |
| **`runtime.memmove`** high | Large copies | Slice growth, `copy`, conversions |
| **`runtime.scanobject`** high | GC tracing many pointers | Fewer pointers in hot structs, value types in slices |
| `alloc_objects` high, `inuse_space` flat | Churn, short-lived allocs | Reduce per-call allocations |
| `inuse_space` grows over time | Leak or unbounded cache | Two heap snapshots, **-base** diff |
| Mutex/block profiles hot | Contention, not raw CPU | Shrink critical sections, shard locks, fewer shared channels |

## Symptom → profile (quick)

| Symptom | Start here |
| --- | --- |
| CPU pegged, slow handler | CPU profile |
| GC pauses, high alloc rate | Heap `-alloc_objects` |
| RSS / heap growing | Heap `-inuse_space`, two snapshots + `-base` |
| Goroutine count exploding | Goroutine profile or `?debug=2` |
| Lock storms | Mutex profile (enable fraction first) |
| Everything blocked | Block profile (enable rate first) |

## Quick reference

| Command | Purpose |
| --- | --- |
| `go test -cpuprofile cpu.prof ./...` | CPU profile during tests |
| `go test -memprofile mem.prof ./...` | Heap profile during tests |
| `go tool pprof cpu.prof` | Interactive REPL |
| `go tool pprof -top cpu.prof` | Top functions by flat cost |
| `go tool pprof -cum -top cpu.prof` | Top by cumulative cost |
| `go tool pprof -http=:8080 cpu.prof` | Web UI |
| `go tool pprof -alloc_objects mem.prof` | Heap: allocation counts |
| `go tool pprof -inuse_space mem.prof` | Heap: live bytes |
| `go tool pprof -base a.prof b.prof` | Diff `b` vs `a` |
| `go tool pprof http://host:6060/debug/pprof/profile?seconds=30` | Live CPU sample |

## pprof vs execution trace

- **`go tool pprof`**: statistical samples (CPU stacks, heap, mutex waits). Best for “which functions cost time or memory?”
- **`go tool trace`**: timeline of scheduling, syscalls, GC, goroutine lifetimes. Best for latency spikes, unfair scheduling, or “what happened in this 200ms window?”

Use both: pprof finds **where**; trace finds **ordering and stalls**.

## Production and security

- Do not expose `/debug/pprof` on the public internet without authentication, TLS, and network controls.
- Prefer a separate admin listener, IP allowlists, or authenticated reverse proxy.
- Mutex and block profiling add overhead—enable only while diagnosing, then disable.
- For profiles taken on a server, symbolization may need the **same binary** (or debug info). Set `PPROF_BINARY_PATH` if `go tool pprof` cannot find local copies of the built binary.

## Save profiles for later analysis

```bash
curl -o cpu.prof 'http://localhost:6060/debug/pprof/profile?seconds=30'
curl -o heap.prof http://localhost:6060/debug/pprof/heap
go tool pprof -http=:8080 cpu.prof
```

Share **`proto`** output if you need to filter in pprof and send a smaller artifact (see `help` in interactive mode for `proto`).

## Goroutine profile from code

```go
f, _ := os.Create("goroutine.prof")
defer f.Close()
_ = pprof.Lookup("goroutine").WriteTo(f, 0)
```

## More one-shot reports

```bash
go tool pprof -text -nodecount=30 cpu.prof
go tool pprof -svg -focus=mypkg -ignore=runtime cpu.prof > focused.svg
go tool pprof -weblist=MyFunc cpu.prof
go tool pprof -disasm=BenchmarkFoo cpu.prof
go tool pprof -granularity=lines -top cpu.prof
```

## Further reading

- `go tool pprof` documentation: [cmd/pprof](https://pkg.go.dev/cmd/pprof)
- Benchmark comparison workflow: `references/benchmarking.md` (benchstat)
