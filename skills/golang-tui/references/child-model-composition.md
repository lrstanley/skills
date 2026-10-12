# Child Model Composition

## Component Interface Pattern

For child components that are internally developed, which are not the root model,
define a `Component`-style interface that returns only `tea.Cmd` from Update
(not `tea.Model`), since components use pointer receivers and mutate in place:

```go
type Component interface {
    Init()              tea.Cmd
    Update(msg tea.Msg) tea.Cmd
    View()              string     // Or *lipgloss.Layer
    GetHeight()         int        // Optional
    GetWidth()          int        // Optional
    GetSize()           (x, y int) // Optional
}
```

The key difference from `tea.Model`: Update returns `tea.Cmd` only, and the component
is a pointer receiver that mutates in place rather than returning a new copy.

More complex example:

```go
type Page interface {
    UUID()                string
    Init()                tea.Cmd
    Update(msg tea.Msg)   tea.Cmd
    View()                string
    GetHeight()           int
    GetWidth()            int
    GetSize()             (x, y int)
    HasInputFocus()       bool
    GetRefreshInterval()  time.Duration
    GetSupportFiltering() bool
    ShortHelp()           []key.Binding
    FullHelp()            [][]key.Binding
    GetTitle()            string
    Close()               tea.Cmd
}
```

### Base Struct for Embedding

Provide a base struct with default implementations for common fields:

```go
type ComponentModel struct {
    Height int
    Width  int
}

func (b *ComponentModel) Init() tea.Cmd       { return nil }
func (b *ComponentModel) Update(msg tea.Msg)  tea.Cmd { return nil }
func (b *ComponentModel) View() string        { return "" }
func (b *ComponentModel) GetHeight() int      { return b.Height }
func (b *ComponentModel) GetWidth() int       { return b.Width }
func (b *ComponentModel) GetSize() (int, int) { return b.Width, b.Height }
```

Components embed `ComponentModel` and override methods as needed:

```go
type MyPanel struct {
    types.ComponentModel
    items []Item
}

func NewMyPanel() *MyPanel {
    return &MyPanel{}
}

func (p *MyPanel) Init() tea.Cmd { return nil }

func (p *MyPanel) Update(msg tea.Msg) tea.Cmd {
    // handle messages, mutate p directly
    return nil
}

func (p *MyPanel) View() string {
    var b strings.Builder
    for _, item := range p.items {
        b.WriteString(item.String())
        b.WriteByte('\n')
    }
    return b.String()
}

func (p *MyPanel) GetTitle() string {
    return fmt.Sprintf("My Panel (%d items)", len(p.items))
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
```

### Transitions

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
            return m, m.detail.Init()
        }
    }
```

### View Routing

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

## Focus Management

### Focus IDs

Define typed focus identifiers for routing input:

```go
type FocusID string

const (
    FocusPage      FocusID = "page"
    FocusDialog    FocusID = "dialog"
    FocusStatusBar FocusID = "statusbar"
)

type FocusChangedMsg struct{ ID FocusID }

func FocusChange(id FocusID) tea.Cmd {
    return func() tea.Msg { return FocusChangedMsg{ID: id} }
}
```

### Tab Navigation

```go
type focusState int

const (
    focusList focusState = iota
    focusInput
    focusButtons
)

func (m *Model) prevFocus() tea.Cmd {
    m.focus = min(m.focus - 1, 0)
    return m.applyFocus()
}

func (m *Model) nextFocus() tea.Cmd {
    m.focus = max(m.focus + 1, 2)
    return m.applyFocus()
}

func (m *Model) applyFocus() tea.Cmd {
    m.input.Blur()
    switch m.focus {
    case focusInput:
        return m.input.Focus()
    }
    return nil
}

// In Update:
case tea.KeyPressMsg:
    switch {
    case key.Matches(msg, types.KeyTabForward):
        return m, m.nextFocus()
    case key.Matches(msg, types.KeyTabBackward):
        return m, m.prevFocus()
    }
```

### Route Input to Focused Component

Only forward keyboard messages to the focused component:

```go
switch msg.(type) {
case tea.KeyPressMsg:
    switch m.focus {
    case focusList:
        m.list, cmd = m.list.Update(msg)
    case focusInput:
        m.input, cmd = m.input.Update(msg)
    }
}
```

Non-keyboard messages (WindowSizeMsg, tick messages, etc) should still go to all components.

## Dialog Overlay Pattern

Separate page and dialog state so dialogs can overlay any page:

```go
type Model struct {
    focus   FocusID
    page    PageComponent
    dialog  DialogComponent  // nil when no dialog is open
}

func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case FocusChangedMsg:
        m.focus = msg.ID

    case tea.KeyPressMsg:
        switch m.focus {
        case FocusDialog:
            if m.dialog != nil {
                return m, m.dialog.Update(msg)
            }
        case FocusPage:
            return m, m.page.Update(msg)
        }
    }
    return m, nil
}

func (m Model) View() tea.View {
    content := m.page.View()
    if m.dialog != nil {
        // Use lipgloss compositor for overlay.
        page := lipgloss.NewLayer(content)

        // Could be extended to multiple dialogs.
        dialog := lipgloss.NewLayer(m.dialog.View()).
            X(m.width/4).Y(m.height/4).Z(1)
        content = lipgloss.NewCompositor(page, dialog).Render()
    }
    return tea.NewView(content)
}
```

### Opening and Closing Dialogs

```go
type OpenDialogMsg struct{ Dialog DialogComponent }
type CloseDialogMsg struct{}

func OpenDialog(d DialogComponent) tea.Cmd {
    return tea.Batch(
        func() tea.Msg { return OpenDialogMsg{Dialog: d} },
        FocusChange(FocusDialog),
    )
}

func CloseDialog() tea.Cmd {
    return tea.Batch(
        func() tea.Msg { return CloseDialogMsg{} },
        FocusChange(FocusPage),
    )
}
```

## UUID-Based Entity Identification

When your TUI manages multiple entities of the same type (tabs, connections, sessions),
assign each a unique ID (e.g. using `github.com/segmentio/ksuid`) for navigation and
message routing:

```go
import "github.com/segmentio/ksuid"

func init() {
    ksuid.SetRand(ksuid.FastRander)
}

type uuid struct {
    once  sync.Once
    value string
}

func (u *uuid) String() string {
    u.once.Do(func() { u.value = ksuid.New().String() })
    return u.value
}

type Component interface {
    UUID() string
    // [...]
}

type ComponentModel struct {
    uuid uuid // Don't need to instantiate this, due to how [sync.Once] is used.
    // [...]
}

func (c *ComponentModel) UUID() string {
    return c.uuid.String()
}
```
