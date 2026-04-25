# View & Styling

## View Must Be Pure

No side effects, no mutations, no I/O. View is called after every Update.

```go
func (m Model) View() tea.View {
    if m.err != nil {
        return tea.NewView(errorStyle.Render(fmt.Sprintf("Error: %v", m.err)))
    }
    if m.state == viewLoading {
        return tea.NewView(m.spinner.View() + " Loading...")
    }

    var b strings.Builder
    b.WriteString(m.renderHeader())
    b.WriteByte('\n')
    b.WriteString(m.renderContent())
    b.WriteByte('\n')
    b.WriteString(m.renderFooter())

    v := tea.NewView(b.String())
    v.AltScreen = true
    return v
}
```

## Define Styles at Package Level

Creating styles in View causes allocations on every render:

```go
// BAD: allocates every render
func (m Model) View() tea.View {
    style := lipgloss.NewStyle().Bold(true)
    return tea.NewView(style.Render("Hello"))
}

// GOOD: defined once
var titleStyle = lipgloss.NewStyle().
    Bold(true).
    Foreground(lipgloss.Color("205"))

func (m Model) View() tea.View {
    return tea.NewView(titleStyle.Render("Hello"))
}
```

For theme-dependent styles, rebuild them when the theme changes (e.g. `ThemeUpdatedMsg`) and store
on the model or in a package-level cache.

```go
type SomeModel struct {
    // [...]

    // Child components.
    list    list.Model

    // Styles.
    titleStyle lipgloss.Style
    errorStyle lipgloss.Style
}

func (m *SomeModel) updateStyles() {
    m.titleStyle = lipgloss.NewStyle().
        Bold(true).
        Foreground(styles.Theme().Primary)
    m.errorStyle = lipgloss.NewStyle().
        Foreground(styles.Theme().Error)

    // Make sure to update child components too.
    m.list.Styles.Title = m.titleStyle
}

func (m *SomeModel) Update(msg tea.Msg) tea.Cmd {
    switch msg := msg.(type) {
    case styles.ThemeUpdatedMsg:
        m.updateStyles()
    // [...]
    }
    // [...]
    return nil
}
```

## Component Styles (per-instance defaults)

For reusable components where the usage may differ, keep package-level
`lipgloss.Style` vars for the app shell, but give the component its own **styles
struct** and a **`DefaultStyles()`** constructor. The model stores `Styles` on the
struct so hosts can swap or tweak colors and emphasis per use (brand themes, high
contrast, or a minimal vs rich listing without forking `View`).

**Pattern:** one `lipgloss.Style` field per role (cursor row, normal row, error
state); defaults live in `DefaultStyles()`; `New()` assigns `Styles: DefaultStyles()`.

```go
// Styles holds render styles for this component. Replace the whole struct or
// individual fields to match the parent UI. See also [DefaultStyles].
type Styles struct {
    DisabledCursor lipgloss.Style
    Cursor         lipgloss.Style
    Symlink        lipgloss.Style
    Directory      lipgloss.Style
    // [...]
}

func DefaultStyles() Styles {
    return Styles{
        DisabledCursor: lipgloss.NewStyle().Foreground(lipgloss.Color("247")),
        Cursor:         lipgloss.NewStyle().Foreground(lipgloss.Color("212")),
        Symlink:        lipgloss.NewStyle().Foreground(lipgloss.Color("36")),
        Directory:      lipgloss.NewStyle().Foreground(lipgloss.Color("99")),
        // [...]
    }
}

type Model struct {
    styles Styles
    // [...]
}

func New() Model {
    return Model{
        styles: DefaultStyles(),
        // [...]
    }
}

func (m Model) SetStyles(styles Styles) {
    // [...]
}
```

**View** reads only from `m.styles` (and layout dimensions), same as the package-level
rule: do not call `lipgloss.NewStyle()` inside `View` for these roles.

**When to use:** embeddable Bubble Tea components, shared widgets, or any model
where the same `View` implementation should look different depending on context.

**When to stay with package-level vars or model fields only:** a single app screen
with one global theme and no need for per-instance look overrides on the child.

**Theme updates:** if the app fires something like `ThemeUpdatedMsg`, rebuild
`Styles` from the active palette in the parent and assign into the child.

## Color Palette

Define a consistent palette using theme colors:

```go
var (
    colorPrimary   = lipgloss.Color("205")
    colorSecondary = lipgloss.Color("241")
    colorSuccess   = lipgloss.Color("78")
    colorError     = lipgloss.Color("196")
)
```

Or derive from bubbletint (see `references/libraries/bubbletint-v2.md`).

## Adaptive Colors

Support both light and dark terminals:

```go
func newStyles(hasDark bool) Styles {
    ld := lipgloss.LightDark(hasDark)
    return Styles{
        Title: lipgloss.NewStyle().
            Foreground(ld(lipgloss.Color("#5A56E0"), lipgloss.Color("#7571F9"))),
        Subtle: lipgloss.NewStyle().
            Foreground(ld(lipgloss.Color("#999"), lipgloss.Color("#666"))),
    }
}
```

Detect in Update via `tea.BackgroundColorMsg`:

```go
case tea.BackgroundColorMsg:
    m.styles = newStyles(msg.IsDark())
```

## Responsive Layout

Always use stored dimensions from `tea.WindowSizeMsg`. Never hardcode terminal dimensions.

### Full-bleed vs inset width (common bug)

Use **one width budget per layout region**, derived from what actually constrains
that region. A single `contentW := m.width - N` reused for every block is a frequent
source of off-by-N gaps (e.g. a bordered header bar stopping short of the screen edge).

- **Full-bleed** chrome (status bar, header box that spans the terminal): set the
  block’s outer width to `m.width` (or the parent content width) unless a **real**
  outer margin/padding applies in that same view branch.
- **Inset** content (form fields under `Padding(0, 2)`, sidebar gutter, split panes):
  subtract only the margins/padding/borders **that wrap that content**, e.g.
  `m.width - outerPaddingLeft - outerPaddingRight`.

```go
// Inset: this branch wraps content with Padding(0, 2) -> 4 columns horizontal inset.
formW := max(0, m.width-4)

// Full-bleed: no horizontal padding on this branch -> use full terminal width.
header := headerStyle.Width(m.width).Render(...)
```

Do not subtract "form gutter" width from list-mode or header widgets unless those
widgets live inside the same padded container.

### Truncation inside bordered / padded blocks

`lipgloss` `Width(w)` on a style usually sets the **outer** width of the rendered
block (including border and padding). Plain-text truncation (`ansi.Truncate`,
runewidth) must use the **inner** text budget:

```go
inner := max(0, m.width-boxStyle.GetHorizontalFrameSize())
text := ansi.Truncate(raw, inner, "…")
out := boxStyle.Width(m.width).Render(text)
```

## Weight-Based Layout

Use proportional weights instead of fixed pixel widths. Weights scale correctly
across any terminal size.

```go
const (
    leftWeight = 1
    rightWeight = 1
)

// Calculate:
totalWeight := leftWeight + rightWeight
leftWidth := (totalWidth * leftWeight) / totalWeight
rightWidth := totalWidth - leftWidth
```

### Common Weight Patterns

```go
// Equal split (50/50): weights 1 and 1
//   leftW = (totalWidth * 1) / (1 + 1)
//   rightW = totalWidth - leftW

// Accordion: focused panel gets 2x weight (about 66/33)
//   if focus is left:  use weights 2 and 1
//   if focus is right: use weights 1 and 2
//   same formula as above with leftWeight/rightWeight taken from that pair

// Three panels (50/25/25): e.g. main weight 2, each side weight 1
//   totalW = 2 + 1 + 1
//   mainW = (totalWidth * 2) / totalW
//   remaining = totalWidth - mainW
//   each sideW = remaining / 2  // adjust if you need a splitter column between them

// Preview mode (75/25): weights 3 and 1
//   contentW = (totalWidth * 3) / (3 + 1)
//   previewW = totalWidth - contentW
```

### Weight-Based Rendering

```go
const (
    leftWeight  = 1
    rightWeight = 1
)

func (m *ChildModel) Update(msg tea.Msg) tea.Cmd {
    switch msg := msg.(type) {
    case tea.WindowSizeMsg:
        m.height = msg.Height
        m.width = msg.Width

        // Calculate the weights.
        totalWeight := leftWeight + rightWeight
        m.leftPanelWidth = (m.width * leftWeight) / totalWeight
        m.rightPanelWidth = m.width - m.leftPanelWidth
        return nil
    // [...]
    }
    // [...]
    return nil
}

func (m *ChildModel) View() string {
    return lipgloss.JoinHorizontal(
        lipgloss.Top,
        panelStyle.Width(m.leftPanelWidth).Render(m.leftContent()),
        panelStyle.Width(m.rightPanelWidth).Render(m.rightContent()),
    )
}
```

## Border Accounting

Borders and padding add to the **frame** of a block. Prefer `GetHorizontalFrameSize()` /
`GetVerticalFrameSize()` on the same `lipgloss.Style` you render with, so border
width, padding, and margins stay in sync if the style changes.

### Vertical

Borders add to the total height. Subtract 2 (top + bottom border) from content
height calculations (or use `GetVerticalBorderSize()` on the style if available), e.g:

```go
func (m *ChildModel) Update(msg tea.Msg) tea.Cmd {
    switch msg := msg.(type) {
    case tea.WindowSizeMsg:
        m.height = msg.Height
        m.width = msg.Width

        m.contentPanel.SetHeight(m.height - 3 - 1 - m.contentStyles.GetVerticalBorderSize()) // 3 = title bar, 1 = status bar
        return nil
    // [...]
    }
    // [...]
```
