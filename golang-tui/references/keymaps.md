# Keymaps

Centralize all key bindings in a single file (`internal/types/keymap.go`). This
avoids scattered string literals and enables consistent help text generation.

## Defining Key Bindings

Use package-level `key.Binding` variables with `key.WithKeys` and `key.WithHelp`:

```go
package types

import "charm.land/bubbles/v2/key"

var (
    // Navigation
    KeyUp = key.NewBinding(
        key.WithKeys("up", "k"),
        key.WithHelp("up/k", "up"),
    )
    KeyDown = key.NewBinding(
        key.WithKeys("down", "j"),
        key.WithHelp("down/j", "down"),
    )
    KeyLeft = key.NewBinding(
        key.WithKeys("left", "h"),
        key.WithHelp("left/h", "left"),
    )
    KeyRight = key.NewBinding(
        key.WithKeys("right", "l"),
        key.WithHelp("right/l", "right"),
    )
    KeyPageUp = key.NewBinding(
        key.WithKeys("b", "pgup"),
        key.WithHelp("b/pgup", "page up"),
    )
    KeyPageDown = key.NewBinding(
        key.WithKeys("f", "pgdown"),
        key.WithHelp("f/pgdn", "page down"),
    )
    KeyGoToTop = key.NewBinding(
        key.WithKeys("home", "g"),
        key.WithHelp("g/home", "go to start"),
    )
    KeyGoToBottom = key.NewBinding(
        key.WithKeys("end", "G"),
        key.WithHelp("G/end", "go to end"),
    )

    // Actions
    KeySelectItem = key.NewBinding(
        key.WithKeys("enter"),
        key.WithHelp("enter", "select"),
    )
    KeyCancel = key.NewBinding(
        key.WithKeys("esc"),
        key.WithHelp("esc", "cancel"),
    )
    KeyFilter = key.NewBinding(
        key.WithKeys("/", "ctrl+f"),
        key.WithHelp("/", "filter"),
    )
    KeyRefresh = key.NewBinding(
        key.WithKeys("ctrl+r"),
        key.WithHelp("ctrl+r", "refresh"),
    )
    KeyCopy = key.NewBinding(
        key.WithKeys("c"),
        key.WithHelp("c", "copy"),
    )
    KeyDelete = key.NewBinding(
        key.WithKeys("ctrl+d"),
        key.WithHelp("ctrl+d", "delete"),
    )
    KeyOpenEditor = key.NewBinding(
        key.WithKeys("ctrl+e"),
        key.WithHelp("ctrl+e", "open in editor"),
    )

    // Focus
    KeyTabForward = key.NewBinding(
        key.WithKeys("tab"),
        key.WithHelp("tab", "next"),
    )
    KeyTabBackward = key.NewBinding(
        key.WithKeys("shift+tab"),
        key.WithHelp("shift+tab", "previous"),
    )

    // Global
    KeyHelp = key.NewBinding(
        key.WithKeys("?"),
        key.WithHelp("?", "help"),
    )
    KeyQuit = key.NewBinding(
        key.WithKeys("ctrl+c"),
        key.WithHelp("ctrl+c", "quit"),
    )
)
```

## Binding Collections

Group related bindings for bulk operations & help text generation:

```go
var KeysNavigation = []key.Binding{
    KeyUp, KeyDown, KeyLeft, KeyRight,
    KeyPageUp, KeyPageDown,
    KeyGoToTop, KeyGoToBottom,
}
```

## Component KeyMaps (per-instance defaults)

For reusable components where the usage may differ, keep package-level `key.Binding` vars
for the app shell, but give the component its own keymap **struct** and a
**`DefaultKeyMap()` constructor**. The model stores `KeyMap` on the struct so
callers can swap or tweak bindings per use (different modes, user preferences, or
avoiding conflicts when the same component is embedded in different parents).

**Pattern:** one `key.Binding` field per logical action; defaults live in
`DefaultKeyMap()`; `New()` assigns `KeyMap: DefaultKeyMap()`.

```go
// KeyMap holds bindings for this component. Swap the whole struct or individual
// fields to customize behavior without forking the Update logic. See also
// [DefaultKeyMap].
type KeyMap struct {
    GoToTop  key.Binding
    GoToLast key.Binding
    Down     key.Binding
    Up       key.Binding
    PageUp   key.Binding
    PageDown key.Binding
    Back     key.Binding
    Open     key.Binding
    Select   key.Binding
}

func DefaultKeyMap() KeyMap {
    return KeyMap{
        GoToTop:  key.NewBinding(key.WithKeys("g"), key.WithHelp("g", "first")),
        GoToLast: key.NewBinding(key.WithKeys("G"), key.WithHelp("G", "last")),
        Down:     key.NewBinding(key.WithKeys("j", "down", "ctrl+n"), key.WithHelp("j", "down")),
        Up:       key.NewBinding(key.WithKeys("k", "up", "ctrl+p"), key.WithHelp("k", "up")),
        PageUp:   key.NewBinding(key.WithKeys("K", "pgup"), key.WithHelp("pgup", "page up")),
        // Can also reference app shell key bindings too.
        PageDown: types.KeyPageDown,
        Back:     types.KeyBack,
        Open:     types.KeyOpen,
        Select:   types.KeySelect,
    }
}

type Component struct {
    keymap KeyMap
    // [...]
}

func New() Component {
    return Component{
        keymap: DefaultKeyMap(),
        // [...]
    }
}

func (c *Component) SetKeyMap(km KeyMap) {
    // [...]
}
```

**Update** always matches against the instance, not global vars:

```go
case key.Matches(msg, m.keymap.Down):
    // ...
case key.Matches(msg, m.keymap.Open):
    // ...
```

**When to use:** embeddable Bubble Tea components, shared widgets, or any model
where the same `Update` implementation must run with different keys depending on
context (e.g. `enter` means "open" in one screen and "select only" in another:
adjust `Open` and `Select` in `KeyMap` for that instance).

**When to stay with package-level vars:** a single app model with one global
key story and no need for per-instance overrides.

## OverrideHelp

Reuse a binding's keys with different help text for context-specific displays:

```go
func OverrideHelp(b key.Binding, help string) key.Binding {
    return key.NewBinding(
        key.WithKeys(b.Keys()...),
        key.WithHelp(b.Help().Key, help),
    )
}

// Usage: same keys, different description
keySelect := OverrideHelp(KeySelectItem, "open secret")
```

## KeyBindingGroup

Organize bindings into titled groups for structured help display:

```go
type KeyBindingGroup struct {
    Title    string
    Bindings [][]key.Binding
}

var HelpGroups = []KeyBindingGroup{
    {
        Title: "Navigation",
        Bindings: [][]key.Binding{
            {KeyUp, KeyDown, KeyPageUp, KeyPageDown},
            {KeyGoToTop, KeyGoToBottom},
        },
    },
    {
        Title: "Actions",
        Bindings: [][]key.Binding{
            {KeySelectItem, KeyCancel, KeyCopy},
            {KeyFilter, KeyRefresh, KeyDelete},
        },
    },
}
```

## Help Bubble Integration

Implement the `help.KeyMap` interface on your model, component, or a dedicated type:

```go
type AppKeyMap struct{}

func (k AppKeyMap) ShortHelp() []key.Binding {
    return []key.Binding{
        KeyUp, KeyDown, KeySelectItem, KeyHelp, KeyQuit,
    }
}

func (k AppKeyMap) FullHelp() [][]key.Binding {
    return [][]key.Binding{
        {KeyUp, KeyDown, KeyPageUp, KeyPageDown, KeyGoToTop, KeyGoToBottom},
        {KeySelectItem, KeyCancel, KeyFilter, KeyRefresh},
        {KeyCopy, KeyDelete, KeyOpenEditor},
        {KeyTabForward, KeyTabBackward, KeyHelp, KeyQuit},
    }
}
```

## Checking Key Membership

Utility functions for checking if a key is contained in a binding set:

```go
func KeyBindingContains(keys []key.Binding, against key.Binding) bool {
    in := against.Keys()
    for _, k := range keys {
        for _, v := range k.Keys() {
            if slices.Contains(in, v) {
                return true
            }
        }
    }
    return false
}
```

Useful for deciding whether to consume a key press or let it propagate to a child
component for generic page/component wrappers, where the parent doesn't know
exactly which keys are relevant to each child.

## Usage in Update

```go
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
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
    }
    return m, nil
}
```

## Showing Help

Often, the simplest way to show help is to provide a 1 cell tall bar, or section of
a bar, somewhere on the screen, that is always visible and shows the most frequently
used keybinds/help text.

Examples:

```
// Single line, top right, or bottom left
: cmds • / filter • ? help • d details • r recurse

// Or
<:> cmds </> filter <?> help <d> details <r> recurse

// Or, context-specific help in a modal dialog
╭──────────────────────────────────────────╮
│                                          │
│   Are you sure you want to delete this   │
│   item? This action cannot be undone.    │
│                                          │
╰────[y confirm • n cancel • esc close]────╯
```

Alternatively, an out of the box help menu is available in the `charm.land/bubbles/v2/help`
package for more advanced help menu implementations. See `references/libraries/bubbles-v2.md`

## Gotchas

- keybinds targeting " " (space), should always use "space" instead of " ".
- Always show most frequently used keybinds/help text for the user to know what to do. If
  there are extensive keybinds, opt for a separate help menu or dialog.
