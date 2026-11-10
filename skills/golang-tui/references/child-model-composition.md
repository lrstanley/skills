# Child Model Composition

## Component Interface Pattern

For child components that are internally developed, which are not the root model,
define a `Component`-style interface that returns only `tea.Cmd` from Update
(not `tea.Model`), since components use pointer receivers and mutate in place:

```go
type Component interface {
    Init()                         tea.Cmd
    Update(msg tea.Msg)            tea.Cmd
    Layout(ctx bloom.Context)      bloom.Child // bloom.Layouter: the component's node tree
    View()                         string      // Fallback outside a bloom layout
    GetHeight()                    int         // Optional
    GetWidth()                     int         // Optional
    GetSize()                      (x, y int)  // Optional
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
    Layout(bloom.Context) bloom.Child
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

Do not give the base struct a default `Layout`: bloom prefers `Layout` over `View`, so an
embedded empty one would hide a component that only overrides `View`.

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

// Layout and View as shown in "Components as bloom nodes" below.

func (p *MyPanel) GetTitle() string {
    return fmt.Sprintf("My Panel (%d items)", len(p.items))
}
```

### Components as bloom nodes

Internally developed components should implement `bloom.Layouter` and return bloom nodes
from `Layout(ctx bloom.Context) bloom.Child`, instead of flattening themselves to a string
in `View`. Returning nodes keeps the component's internals part of the parent's tree, so
its IDs, mouse handlers, focusable controls, scrolling, and animations work, and it can
change shape with `ctx.Width` / `ctx.Height` rather than taking size options. The parent
still decides the slot (fixed, fill, grow). `Layout` may be called several times per frame,
so treat it like `View`: read state, return nodes, never mutate.

Keep a `View()` that renders the same tree, for use outside a bloom layout (and to satisfy
`bloom.Child`):

```go
func (p *MyPanel) Layout(ctx bloom.Context) bloom.Child {
    rows := make([]bloom.Child, 0, len(p.items))
    for _, item := range p.items {
        rows = append(rows, bloom.Text(item.String()).Truncate())
    }
    return bloom.Column(rows...)
}

func (p *MyPanel) View() string {
    return bloom.Render(0, 0, p.Layout(bloom.Context{})) // natural size
}
```

A plain `View() string` component **can** still be placed in a bloom tree as is, which is
the right choice for Bubbles components and simple leaf widgets with no clickable or
focusable parts. Implement `bloom.Measurer` when such a component knows its size cheaply
(such as a one-row status bar). Components that render from their own size (viewport,
list, table) still get it pushed in from the parent via `bloom.Solve`. Details:
<https://bloomfx.dev/layout/responsive.md> and `references/libraries/bloom.md`. `steep`
can test these components directly with its component harness.

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

Two kinds of focus exist, and they compose:

- **Which child model receives keys** (page vs dialog vs status bar): routed by the parent,
  as shown below.
- **Which control inside a screen is focused** (fields, buttons, panes): prefer
  `bloom.Focus` with focusable node IDs, which gives tab order from the layout, click to
  focus, and focus scopes for dialogs and panels. See <https://bloomfx.dev/input/focus.md>.


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

func (m *Model) layout() bloom.Child {
    var layers []bloom.LayerNode
    if m.dialog != nil {
        // Centered, modal, and dims the page beneath. See bloom docs for
        // transitions (Presence), shadows, anchoring, and stacking.
        layers = append(layers, bloom.Layer(m.dialog).Modal().Backdrop(fx.Dim{Amount: 0.5}))
    }
    return bloom.Overlay(m.page, layers...)
}

func (m *Model) View() tea.View {
    return m.ui.View(m.width, m.height, m.layout())
}
```

Use bloom layers (see `references/libraries/bloom.md` and
<https://bloomfx.dev/layers/dialogs.md>) rather than positioning `lipgloss.Layer`s by hand
with a `Compositor`: bloom centers or anchors the dialog, makes it modal for mouse input,
confines focus to it, and can animate it in and out. Dropdowns and toasts use the same
layer mechanism.

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
