# Bubbles v2

Pre-built TUI components for Bubble Tea. Import: `charm.land/bubbles/v2/<component>`

## How Bubbles Work

Every bubble follows the same pattern:

1. **Model** -- struct holding component state
2. **New()** -- constructor, usually with functional options
3. **Update(msg) (Model, tea.Cmd)** -- processes messages, returns updated model & commands
4. **View() string** -- renders current state

Bubbles return their own Model type from Update (not `tea.Model`). Always assign back:

```go
m.textinput, cmd = m.textinput.Update(msg)  // correct
m.textinput.Update(msg)                      // wrong: discards the update
```

### Message Flow

Forward all messages to embedded bubbles. Most self-filter (spinners ignore wrong IDs,
unfocused inputs ignore keys):

```go
func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    var cmds []tea.Cmd
    var cmd tea.Cmd

    m.spinner, cmd = m.spinner.Update(msg)
    cmds = append(cmds, cmd)

    m.textinput, cmd = m.textinput.Update(msg)
    cmds = append(cmds, cmd)

    return m, tea.Batch(cmds...)
}
```

### Commands and Init

Some bubbles require startup commands. Return them from your `Init()`:

```go
func (m model) Init() tea.Cmd {
    return tea.Batch(m.spinner.Tick, m.timer.Init())
}
```

---

## Component Catalog

### spinner

Animated loading indicator.

```go
import "charm.land/bubbles/v2/spinner"

s := spinner.New(spinner.WithSpinner(spinner.Dot), spinner.WithStyle(myStyle))
```

Presets: `Line`, `Dot`, `MiniDot`, `Jump`, `Pulse`, `Points`, `Globe`, `Moon`,
`Monkey`, `Meter`, `Hamburger`, `Ellipsis`.

Start: return `m.spinner.Tick` from `Init()`.

### textinput

Single-line text input with cursor, placeholder, validation, and autocomplete.

```go
import "charm.land/bubbles/v2/textinput"

ti := textinput.New()
ti.Placeholder = "Type here..."
ti.CharLimit = 100
ti.SetWidth(40)
```

Key methods: `Focus() tea.Cmd`, `Blur()`, `Value() string`, `SetValue(string)`,
`SetSuggestions([]string)`, `Validate ValidateFunc`.

Echo modes: `EchoNormal`, `EchoPassword`, `EchoNone`.

### textarea

Multi-line text editor with line numbers and word wrapping.

```go
import "charm.land/bubbles/v2/textarea"

ta := textarea.New()
ta.SetWidth(60)
ta.SetHeight(10)
ta.Placeholder = "Enter text..."
ta.ShowLineNumbers = true
```

Key methods: `Focus() tea.Cmd`, `Blur()`, `Value() string`, `SetValue(string)`,
`Line() int`, `LineCount() int`.

### list

Full list browser with fuzzy filtering, pagination, help, and status messages.

```go
import "charm.land/bubbles/v2/list"

items := []list.Item{myItem1, myItem2}
l := list.New(items, myDelegate, width, height)
l.Title = "My List"
```

Items must implement `FilterValue() string`. Delegates implement `ItemDelegate`:
`Render`, `Height`, `Spacing`, `Update`.

Key methods: `SetItems([]Item)`, `SelectedItem() Item`, `SetSize(w, h int)`,
`SetFilteringEnabled(bool)`, `NewStatusMessage(string) tea.Cmd`.

Built-in filters: `list.DefaultFilter` (fuzzy), `list.UnsortedFilter`.

### table

Tabular data with row selection and keyboard navigation.

```go
import "charm.land/bubbles/v2/table"

t := table.New(
    table.WithColumns([]table.Column{
        {Title: "Name", Width: 20},
        {Title: "Age", Width: 5},
    }),
    table.WithRows([]table.Row{
        {"Alice", "30"},
        {"Bob", "25"},
    }),
    table.WithHeight(10),
    table.WithFocused(true),
)
```

Key methods: `Focus()`, `Blur()`, `SelectedRow() Row`, `Cursor() int`,
`SetRows([]Row)`, `SetWidth(int)`, `SetHeight(int)`, `UpdateViewport()`.

Styles: `table.Styles{Header, Cell, Selected}`.

### viewport

Scrollable content viewer with vertical/horizontal scrolling, soft wrap, and gutters.

```go
import "charm.land/bubbles/v2/viewport"

vp := viewport.New(viewport.WithWidth(80), viewport.WithHeight(24))
vp.SetContent("long text content here...")
```

Key methods: `SetContent(string)`, `SetContentLines([]string)`, `SetWidth(int)`,
`SetHeight(int)`, `ScrollDown(n)`, `ScrollUp(n)`, `GotoTop()`, `GotoBottom()`,
`AtTop() bool`, `AtBottom() bool`, `ScrollPercent() float64`.

Fields: `SoftWrap bool`, `FillHeight bool`, `MouseWheelEnabled bool`,
`MouseWheelDelta int`, `Style lipgloss.Style`.

Highlighting: `SetHighlights([][]int)`, `HighlightNext()`, `HighlightPrevious()`,
`EnsureVisible(line, colstart, colend int)`.

Gutter: `LeftGutterFunc GutterFunc` for line numbers.

### paginator

Pagination logic and display (dot or numeric style).

```go
import "charm.land/bubbles/v2/paginator"

p := paginator.New(paginator.WithPerPage(10), paginator.WithTotalPages(5))
```

Key methods: `NextPage()`, `PrevPage()`, `SetTotalPages(itemCount int) int`,
`GetSliceBounds(length int) (start, end int)`, `OnFirstPage() bool`, `OnLastPage() bool`.

Types: `Arabic` (1/5), `Dots` (bullet dots).

### progress

Animated progress bar with solid, gradient, and dynamic color fills.

```go
import "charm.land/bubbles/v2/progress"

p := progress.New(progress.WithDefaultBlend(), progress.WithWidth(40))
```

Animated mode: `cmd := m.progress.SetPercent(0.75)` returns a command. Process
`progress.FrameMsg` in Update.

Static mode: `view := m.progress.ViewAs(0.75)` renders directly, no Update needed.

Key methods: `SetPercent(float64) tea.Cmd`, `IncrPercent(float64) tea.Cmd`,
`ViewAs(float64) string`, `SetWidth(int)`, `IsAnimating() bool`.

### help

Auto-generated help view from key bindings.

```go
import "charm.land/bubbles/v2/help"

h := help.New()
h.SetWidth(80)
view := h.View(myKeyMap)
```

Your key map must implement the `help.KeyMap` interface:

```go
import "charm.land/bubbles/v2/key"

func (k KeyMap) ShortHelp() []key.Binding {
    return []key.Binding{k.Quit, k.Help}
}

func (k KeyMap) FullHelp() [][]key.Binding {
    return [][]key.Binding{{k.Quit, k.Help}, {k.Up, k.Down}}
}
```

Toggle short/full with `h.ShowAll`.

### filepicker

File system browser for selecting files/directories.

```go
import "charm.land/bubbles/v2/filepicker"

fp := filepicker.New()
fp.CurrentDirectory = "/home/user"
fp.AllowedTypes = []string{".go", ".md"}
fp.ShowHidden = true
```

Check selection in Update:

```go
m.filepicker, cmd = m.filepicker.Update(msg)
if didSelect, path := m.filepicker.DidSelectFile(msg); didSelect {
    m.selectedFile = path
}
```

### timer

Countdown timer with configurable interval.

```go
import "charm.land/bubbles/v2/timer"

t := timer.New(30*time.Second, timer.WithInterval(100*time.Millisecond))
```

Start: return `m.timer.Init()` from `Init()`.

Key methods: `Start() tea.Cmd`, `Stop() tea.Cmd`, `Toggle() tea.Cmd`,
`Running() bool`, `Timedout() bool`.

Messages: `timer.TickMsg` (has `Timeout bool`), `timer.TimeoutMsg`.

### stopwatch

Count-up timer with start/stop/reset.

```go
import "charm.land/bubbles/v2/stopwatch"

sw := stopwatch.New(stopwatch.WithInterval(100*time.Millisecond))
```

Start: return `m.stopwatch.Init()` from `Init()`.

Key methods: `Start() tea.Cmd`, `Stop() tea.Cmd`, `Toggle() tea.Cmd`,
`Reset() tea.Cmd`, `Elapsed() time.Duration`.

### cursor

Virtual cursor used internally by textinput and textarea.

```go
import "charm.land/bubbles/v2/cursor"
```

Modes: `CursorBlink`, `CursorStatic`, `CursorHide`.

Key methods: `Focus() tea.Cmd`, `Blur()`, `SetMode(Mode) tea.Cmd`.

### key

Non-visual utility for remappable key bindings with help text.

```go
import "charm.land/bubbles/v2/key"

b := key.NewBinding(
    key.WithKeys("k", "up"),
    key.WithHelp("up/k", "move up"),
)

// In Update:
case tea.KeyPressMsg:
    if key.Matches(msg, b) {
        m.cursor--
    }
```

Key methods on Binding: `Enabled() bool`, `SetEnabled(bool)`, `Keys() []string`,
`SetKeys(...string)`, `Help() Help`, `SetHelp(key, desc string)`, `Unbind()`.

---

## Patterns

### Focus Management

```go
for i := range m.inputs {
    m.inputs[i].Blur()
}
cmd := m.inputs[m.focusIndex].Focus()
```

`textinput.Focus()` returns a `tea.Cmd` for cursor blinking. Dropping it means no blink.

### Window Size Handling

```go
case tea.WindowSizeMsg:
    m.viewport.SetWidth(msg.Width)
    m.viewport.SetHeight(msg.Height - headerHeight)
    m.list.SetSize(msg.Width, msg.Height)
    m.table.SetWidth(msg.Width)
    m.table.SetHeight(msg.Height)
    m.progress.SetWidth(msg.Width - padding)
    m.help.SetWidth(msg.Width)
```

### ID-Based Message Routing

Animated bubbles (spinner, progress, timer, stopwatch) use internal IDs. Multiple
instances do not interfere. Forward all messages to all instances:

```go
m.spinner1, cmd1 = m.spinner1.Update(msg)
m.spinner2, cmd2 = m.spinner2.Update(msg)
```

---

## Common Mistakes

- Not returning commands from Update -- Spinner and timer stop working if you drop their commands.
- Forgetting Init/Tick -- Spinner needs `m.spinner.Tick` from Init. Timer needs `m.timer.Init()`.
- Not assigning Update result back -- Bubbles return value types. `m.spinner.Update(msg)` without assignment discards the update.
- Only forwarding messages to focused bubble -- Most bubbles self-filter. Forward to all and let them decide.
- Use `tea.KeyPressMsg` not `tea.KeyMsg`.
- Not handling `tea.WindowSizeMsg` -- Components with fixed dimensions clip/overflow without resize.
- Setting width/height to 0 -- Viewport and table render empty when dimensions are 0.
- Calling `Focus()` without using the cmd -- `textinput.Focus()` returns a `tea.Cmd`. Drop it and the cursor will not blink.
