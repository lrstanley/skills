# Model & Update

## Model Design

```go
type Model struct {
    // Dimensions (from WindowSizeMsg)
    width  int
    height int

    // Model state
    items    []Item
    cursor   int
    selected map[int]struct{}
    state    viewState
    err      error

    // Sub-components
    list     list.Model
    viewport viewport.Model
    spinner  spinner.Model
    help     help.Model
}

var _ tea.Model = (*Model)(nil)
```

Always store `width` and `height` from `tea.WindowSizeMsg`. These drive all layout
calculations in View.

## Init

Init returns the initial command(s). Never perform blocking I/O here.

```go
func (m Model) Init() tea.Cmd {
    return tea.Batch(
        m.spinner.Tick,
        styles.Theme.Init(),
        loadDataCmd(),
    )
}
```

## Update Patterns

### Message Type Switch

```go
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    var cmds []tea.Cmd

    switch msg := msg.(type) {
    case tea.WindowSizeMsg:
        m.width = msg.Width
        m.height = msg.Height
        m.list.SetSize(msg.Width, msg.Height-4)
        m.viewport.SetWidth(msg.Width)
        m.viewport.SetHeight(msg.Height - 4)
    case styles.ThemeUpdatedMsg:
        m.updateStyles()
    case tea.KeyPressMsg:
        switch {
        case key.Matches(msg, types.KeyQuit):
            return m, tea.Quit
        case key.Matches(msg, types.KeyHelp):
            m.help.ShowAll = !m.help.ShowAll
        case key.Matches(msg, types.KeyUp):
            m.cursor--
        case key.Matches(msg, types.KeyDown):
            m.cursor++
        case key.Matches(msg, types.KeySelectItem):
            return m, m.selectCurrent()
        }
    case dataLoadedMsg:
        m.items = msg.items
        m.state = viewList
    case errMsg:
        m.err = msg.err
    }

    // Propagate to sub-components
    var cmd tea.Cmd
    m.spinner, cmd = m.spinner.Update(msg)
    cmds = append(cmds, cmd)

    return m, tea.Batch(cmds...)
}
```

### Always Handle WindowSizeMsg

Sent on startup and every resize. Without it, components have zero dimensions and
render empty.

```go
case tea.WindowSizeMsg:
    m.width = msg.Width
    m.height = msg.Height
    m.viewport.SetWidth(msg.Width)
    m.viewport.SetHeight(msg.Height - headerHeight - footerHeight)
    m.list.SetSize(msg.Width, msg.Height)
    m.table.SetWidth(msg.Width)
    m.progress.SetWidth(msg.Width - padding)
    m.help.SetWidth(msg.Width)
```

### Key Handling with key.Matches

Prefer `key.Matches` with centralized bindings over raw string comparison:

```go
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    var cmds []tea.Cmd

    switch msg := msg.(type) {
    // [...]
    case tea.KeyPressMsg:
        switch {
        case key.Matches(msg, types.KeyQuit):
            return m, tea.Quit
        case key.Matches(msg, types.KeyHelp):
            m.help.ShowAll = !m.help.ShowAll
        case key.Matches(msg, types.KeyUp):
            m.cursor--
        case key.Matches(msg, types.KeyDown):
            m.cursor++
        case key.Matches(msg, types.KeySelectItem):
            return m, m.selectCurrent()
        }
    // [...]
    }

    // [...]
    return m, tea.Batch(cmds...)
}
```

### Sub-Component Propagation

Collect all commands and batch them:

```go
var cmds []tea.Cmd
var cmd tea.Cmd

m.list, cmd = m.list.Update(msg)
cmds = append(cmds, cmd)

m.viewport, cmd = m.viewport.Update(msg)
cmds = append(cmds, cmd)

m.spinner, cmd = m.spinner.Update(msg)
cmds = append(cmds, cmd)

return m, tea.Batch(cmds...)
```

Can also utilize a helper function to reduce the verbosity:

```go
func Propagate[T any](m T, msg tea.Msg, cmds []tea.Cmd) (T, []tea.Cmd) {
    var cmd tea.Cmd
    m, cmd = m.Update(msg)
    if cmd != nil {
        cmds = append(cmds, cmd)
    }
    return m, cmds
}

// Calling:
var cmds []tea.Cmd
m.list, cmds = types.Propagate(m.list, msg, cmds)
m.viewport, cmds = types.Propagate(m.viewport, msg, cmds)
m.spinner, cmds = types.Propagate(m.spinner, msg, cmds)
return m, tea.Batch(cmds...)
```

## Commands

### Commands Return Messages

```go
type itemsFetchedMsg struct{ items []Item }
type errMsg struct{ err error }

func fetchItemsCmd(url string) tea.Cmd {
    return func() tea.Msg {
        resp, err := http.Get(url)
        if err != nil {
            return errMsg{err}
        }
        defer resp.Body.Close()
        var items []Item
        json.NewDecoder(resp.Body).Decode(&items)
        return itemsFetchedMsg{items}
    }
}
```

### CmdMsg Helper

Wrap a message into a command for cleaner dispatch:

```go
func CmdMsg[T any](msg T) tea.Cmd {
    return func() tea.Msg { return msg }
}

// Usage
func AppQuit() tea.Cmd {
    return CmdMsg(AppQuitMsg{})
}

func FocusChange(id FocusID) tea.Cmd {
    return CmdMsg(AppFocusChangedMsg{ID: id})
}
```

### Tick Commands

Ticks fire once. Re-dispatch to keep ticking:

```go
type tickMsg time.Time

func tickCmd() tea.Cmd {
    return tea.Tick(100*time.Millisecond, func(t time.Time) tea.Msg {
        return tickMsg(t)
    })
}

case tickMsg:
    m.frame++
    return m, tickCmd()
```

### Batch Multiple Commands

```go
func (m Model) Init() tea.Cmd {
    return tea.Batch(
        loadConfigCmd(),
        loadDataCmd(),
        m.spinner.Tick,
    )
}
```

## State Machine Pattern

### View States

```go
type viewState int

const (
    viewLoading viewState = iota
    viewList
    viewDetail
    viewEdit
)

type Model struct {
    state  viewState
    list   list.Model
    detail detailModel
    edit   editModel
}
```

### Transitions in Update

```go
case tea.KeyPressMsg:
    switch {
    case key.Matches(msg, types.KeyCancel):
        switch m.state {
        case viewDetail:
            m.state = viewList
        case viewEdit:
            m.state = viewDetail
        }
    case key.Matches(msg, types.KeySelectItem):
        if m.state == viewList {
            m.state = viewDetail
            m.detail = newDetailModel(m.list.SelectedItem())
        }
    }
```

### Routing in View

```go
func (m Model) View() tea.View {
    var content string
    switch m.state {
    case viewLoading:
        content = m.spinner.View() + " Loading..."
    case viewList:
        content = m.list.View()
    case viewDetail:
        content = m.detail.View()
    case viewEdit:
        content = m.edit.View()
    }
    v := tea.NewView(content)
    v.AltScreen = true
    return v
}
```

## Anti-Patterns

### Side Effects in View

```go
// BAD
func (m Model) View() tea.View {
    log.Printf("rendering")
    m.renderCount++
    return tea.NewView("...")
}

// View must be a pure function. No I/O, no mutations.
```

### Blocking in Update

```go
// BAD
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    time.Sleep(2 * time.Second)
    return m, nil
}

// FIX: use tea.Tick for delays, tea.Cmd for I/O
```

### Not Batching Commands

```go
// BAD: only returns last command
func (m Model) Init() tea.Cmd {
    loadConfig()
    return loadData()
}

// FIX: batch all init commands
func (m Model) Init() tea.Cmd {
    return tea.Batch(loadConfigCmd(), loadDataCmd())
}
```
