# Performance

## ANSI-Aware String Functions

`github.com/charmbracelet/x/ansi` (and lipgloss/bubbletea helpers) provide string
operations that correctly handle ANSI escape sequences. Always use these instead
of standard library string functions when working with styled text.

### Width Measurement

```go
import "github.com/charmbracelet/x/ansi"

// BAD: counts escape sequence bytes, incorrectly measures width for double-width & zero-width characters
w := len(styledString)

// GOOD: counts visible cell width
w := ansi.StringWidth(styledString) // Does not account for width over multiple lines

// Also available via lipgloss
w := lipgloss.Width(styledString) // accounts for max length over multiple newlines
h := lipgloss.Height(styledString)
```

`ansi.StringWidth` handles:

- ANSI escape sequences (ignored in width calculation)
- Double-width characters (CJK, emoji)
- Zero-width characters (combining marks)

### Truncation

```go
// Truncate to maxWidth visible cells, append tail if truncated
s := ansi.Truncate(styledString, maxWidth, "...")
```

Use this instead of string slicing which breaks ANSI sequences:

```go
// BAD: breaks escape sequences
s := styledString[:40]

// GOOD: ANSI-aware truncation
s := ansi.Truncate(styledString, 40, "...")
```

### Cutting

```go
// Extract visible cells, preserving ANSI state
s := ansi.Cut(styledString, start, end)
```

### Stripping

```go
// Remove all ANSI escape sequences
plain := ansi.Strip(styledString)
```

### Text Wrapping

```go
// Word wrap at width (preserves ANSI, breaks at spaces)
s := ansi.Wordwrap(text, width)

// Wrap with custom break points
s := ansi.Wrap(text, width) // Or lipgloss.Wrap(text, width, " "), which uses this behind the scenes

// Hard wrap at exact width (breaks mid-word)
s := ansi.Hardwrap(text, width)
```

## View() Optimization

View is called after every Update. Keep it fast.

### Use strings.Builder

```go
func (m Model) renderContent() string {
    var b strings.Builder
    b.Grow(m.height * m.width)

    for i, item := range m.visibleItems() {
        if i == m.cursor {
            b.WriteString(selectedStyle.Render("> " + item.Title))
        } else {
            b.WriteString(itemStyle.Render("  " + item.Title))
        }
        b.WriteByte('\n')
    }
    return b.String()
}
```

### Package-Level Style Definitions

```go
// BAD: allocates every render
func (m Model) View() tea.View {
    style := lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("205"))
    return tea.NewView(style.Render("text"))
}

// GOOD: defined once at package level
var titleStyle = lipgloss.NewStyle().
    Bold(true).
    Foreground(lipgloss.Color("205"))

func (m Model) View() tea.View {
    return tea.NewView(titleStyle.Render("text"))
}
```

For theme-dependent styles, store them on the model and rebuild only when receiving
a message from the parent that the theme has changed.

### Pre-Compute in Update

Move expensive calculations from View to Update. Store pre-rendered fragments.
Ensure it's updated when the data, theme, window size, or similar state changes.

```go
func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case dataLoadedMsg:
        m.items = msg.items
        m.renderedItems = m.preRenderItems()
    }
    return m, nil
}

func (m Model) View() tea.View {
    return tea.NewView(m.renderedItems)
}
```

### Limit Visible Items

Only render what is visible. For long lists, slice to the viewport:

```go
func (m Model) visibleItems() []Item {
    start := m.offset
    end := min(start+m.height, len(m.items))
    return m.items[start:end]
}
```

## FPS Control

For heavy UIs, cap the render frequency:

```go
p := tea.NewProgram(model{}, tea.WithFPS(30))  // default is 60
```

Lower FPS reduces CPU usage at the cost of visual smoothness.

## Avoid len() on Styled Strings

```go
// BAD: includes ANSI escape bytes
if len(styledText) > maxWidth {
    // ...
}

// GOOD: measures visible width
if ansi.StringWidth(styledText) > maxWidth {
    // ...
}
```

This matters for:

- Layout calculations with styled strings
- Truncation decisions
- Padding calculations

## Allocation-Heavy Anti-Patterns

### String Concatenation in Loops

```go
// BAD: O(n^2) allocations
var result string
for _, item := range items {
    result += item.Render() + "\n"
}

// GOOD: single allocation
var b strings.Builder
for _, item := range items {
    b.WriteString(item.Render())
    b.WriteByte('\n')
}
result := b.String()
```

### Fmt.Sprintf in Hot Paths

```go
// BAD: allocates format string and result
label := fmt.Sprintf("%s: %d", name, count)

// GOOD: use builder for simple concatenation
var b strings.Builder
b.WriteString(name)
b.WriteString(": ")
b.WriteString(strconv.Itoa(count))
label := b.String()
```

Reserve `fmt.Sprintf` for complex formatting. Use builders for simple joins.

## Benchmarking Views

```bash
go test -bench BenchmarkView -benchmem ./internal/ui/...
```

```go
func BenchmarkView(b *testing.B) {
    m := newTestModel()
    m.width = 120
    m.height = 40

    for b.Loop() {
        _ = m.View()
    }
}
```

Track `allocs/op` to catch regressions in rendering allocation count.

## Quick Reference

| Function | Purpose |
| --- | --- |
| `ansi.StringWidth(s)` | Visible cell width (ANSI-aware) |
| `ansi.Truncate(s, w, tail)` | Truncate to width with tail |
| `ansi.Cut(s, start, end)` | Extract visible cell range |
| `ansi.Strip(s)` | Remove ANSI sequences |
| `ansi.Wordwrap(s, w)` | Word wrap preserving ANSI |
| `ansi.Wrap(s, w)` | Wrap with custom breaks |
| `ansi.Hardwrap(s, w)` | Hard wrap at exact width |
| `lipgloss.Width(s)` | `ansi.StringWidth` but accounts for max length over multiple newlines |
| `lipgloss.Height(s)` | Count newlines |
| `lipgloss.Size(s)` | Width and height |
| `lipgloss.Wrap(s, w, breakChars)` | Word wrap preserving ANSI |
