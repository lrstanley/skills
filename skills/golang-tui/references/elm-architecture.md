# Elm Architecture

## Commands Are Data

The most important concept: commands describe effects, they do not execute them.

```go
type Cmd func() Msg // tea.Cmd / tea.Msg
```

When you return a `tea.Cmd` from `Update()`, you return a *description* of work.
The Bubble Tea runtime executes it asynchronously after `Update()` returns.

## Execution Model

```
User Input / Timer / External
           |
           v
    +----------+     returns        +--------------+
    |  Update  | -----------------> | Model + Cmd  |
    +----------+    immediately     +------+-------+
                                           |
                    +----------------------+
                    v
             +-----------+
             |  Runtime  |  executes Cmd in
             |  runs Cmd |  background goroutine
             +-----+-----+
                    |
                    v  sends Msg
             +----------+
             |  Update  |  <-- cycle continues
             +----------+
```

`Update()` must return quickly. The runtime handles all async work.

## NOT Issues (Avoid False Positives)

### Helper functions returning tea.Cmd

```go
func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    return m, m.fetchItems()
}

func (m *model) fetchItems() tea.Cmd {
    return func() tea.Msg {
        items, _ := api.GetItems()
        return itemsMsg{items}
    }
}
```

`m.fetchItems()` creates and returns a command descriptor. The `http.Get` inside
the closure does NOT run during Update. The runtime calls the closure later.

### Value receivers on Update

```go
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    m.counter++
    return m, nil
}
```

Bubble Tea returns the root `tea.Model` by value. The caller receives the modified copy.

### Nested model updates

```go
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    var cmd tea.Cmd
    m.child, cmd = m.child.Update(msg)
    return m, cmd
}
```

Child Update is also non-blocking. Commands bubble up through the parent.

### Batch commands

```go
return m, tea.Batch(m.loadUser(), m.loadPosts(), m.loadSettings())
```

All three commands run concurrently by the runtime.

### Sequential Commands

```go
return m, tea.Sequence(m.loadUser(), m.loadPosts(), m.loadSettings())
```

All three commands run sequentially by the runtime.

## ACTUAL Issues

### Blocking I/O in Update

```go
// BAD
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    data, _ := os.ReadFile("config.json")
    m.config = parse(data)
    return m, nil
}

// FIX: move to a command
func loadConfig() tea.Cmd {
    return func() tea.Msg {
        data, err := os.ReadFile("config.json")
        if err != nil {
            return errMsg{err}
        }
        return configLoadedMsg{data}
    }
}
```

### Sleep in Update

```go
// BAD
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    time.Sleep(2 * time.Second)
    return m, nil
}

// FIX: use tea.Tick
return m, tea.Tick(2*time.Second, func(t time.Time) tea.Msg {
    return delayCompleteMsg{}
})
```

### Blocking channel reads

```go
// BAD
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    data := <-m.dataChan
    return m, nil
}

// FIX: use a command
func waitForData(ch chan dataMsg) tea.Cmd {
    return func() tea.Msg { return <-ch }
}
```

## Quick Reference

| Pattern | Blocking? | Why |
| --- | --- | --- |
| `return m, m.loadData()` | No | Returns command descriptor |
| `data := fetchData()` in Update | **Yes** | Direct I/O call |
| `return m, func() tea.Msg { ... }` | No | Closure runs later |
| `time.Sleep(d)` in Update | **Yes** | Blocks goroutine |
| `<-channel` in Update | **Maybe** | Blocks if empty |
| `return m, tea.Tick(d, ...)` | No | Runtime handles delay |

See `references/child-model-composition.md` for the Component interface pattern
used by internally-developed child components.
