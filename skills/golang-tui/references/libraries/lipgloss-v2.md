# Lip Gloss v2

CSS-like terminal styling for Go. Import: `charm.land/lipgloss/v2`

Sub-packages:

- `charm.land/lipgloss/v2/table`
- `charm.land/lipgloss/v2/list`
- `charm.land/lipgloss/v2/tree`

## Quick Start

```go
package main

import "charm.land/lipgloss/v2"

func main() {
    style := lipgloss.NewStyle().
        Bold(true).
        Foreground(lipgloss.Color("#FAFAFA")).
        Background(lipgloss.Color("#7D56F4")).
        Padding(1, 2).
        Width(30)

    lipgloss.Println(style.Render("Hello, terminal!"))
}
```

Use `lipgloss.Println` (not `fmt.Println`) for automatic color downsampling in
standalone apps. Inside Bubble Tea, the runtime handles downsampling.

## Style

`Style` is a value type. Assignment copies. No renderer, no pointers.

```go
s := lipgloss.NewStyle().
    Bold(true).Italic(true).Faint(true).Strikethrough(true).Reverse(true).
    Underline(true).
    UnderlineStyle(lipgloss.UnderlineCurly).
    UnderlineColor(lipgloss.Color("#FF0000")).
    Foreground(lipgloss.Color("#FF0000")).
    Background(lipgloss.Color("63")).
    Width(40).Height(10).MaxWidth(80).MaxHeight(20).
    Align(lipgloss.Center).
    Padding(1, 2).PaddingChar('.').
    Margin(1, 2).MarginBackground(c).
    Border(lipgloss.RoundedBorder()).
    BorderForeground(lipgloss.Color("63")).
    Inline(true).
    Transform(strings.ToUpper).
    Hyperlink("https://example.com")

output := s.Render("text", "more")
```

Position constants: `Left`/`Top` (0.0), `Center` (0.5), `Right`/`Bottom` (1.0).

Padding/Margin shorthand follows CSS:

- 1 arg = all
- 2 args = vertical/horizontal
- 3 args = top/horizontal/bottom
- 4 args = top/right/bottom/left

Underline styles: `UnderlineNone`, `UnderlineSingle`, `UnderlineDouble`, `UnderlineCurly`,
`UnderlineDotted`, `UnderlineDashed`.

`Width` includes padding and borders. `Width(40)` is 40 total cells, not content width.

Inheritance: `child.Inherit(parent)` copies unset rules. Margins/padding are NOT inherited.

### Style getters (layout math)

Use these on a configured `lipgloss.Style` when you need numbers for dynamic layouts: how
much horizontal or vertical space the style consumes, content box size, or per-side
breakdowns. They reflect the rules already set on that style (they do not measure a
rendered string; for that use `lipgloss.Size` / `Width` / `Height` on output).

**Block size from constraints** -- `GetWidth()`, `GetHeight()`, `GetMaxWidth()`,
`GetMaxHeight()`.

**Frame totals (border + margin + padding on each axis)** --
`GetHorizontalFrameSize()`, `GetVerticalFrameSize()`.

**Margins** -- axis sums: `GetHorizontalMargins()`, `GetVerticalMargins()`; per side,
use the `GetMargin*` methods.

**Padding** -- axis sums: `GetHorizontalPadding()`, `GetVerticalPadding()`; per side,
use the `GetPadding*` methods.

**Borders** -- axis sums: `GetHorizontalBorderSize()`, `GetVerticalBorderSize()`; per
side, use the `GetBorder*Size` methods; also `GetBorderTopWidth()` when the top rule width
matters separately from the generic top size. With `BorderForegroundBlend`, use
`GetBorderForegroundBlendOffset()` for blend alignment math.

**Other** -- `GetTabWidth()` (tab stop width when expanding tabs in rendered text).

Typical use: subtract `GetHorizontalFrameSize()` from a fixed column width to get usable
content width, or combine margin and padding getters with `JoinHorizontal` /
`JoinVertical` to align unrelated blocks.

## Color

All color types implement `image/color.Color`.

```go
lipgloss.Color("#FF0000")        // hex TrueColor
lipgloss.Color("#F00")           // short hex
lipgloss.Color("21")             // ANSI256
lipgloss.Color("5")              // ANSI 16
lipgloss.Magenta                 // named constant (ansi.BasicColor)
lipgloss.NoColor{}               // absence of color
lipgloss.RGBColor{R: 255}        // direct RGB
lipgloss.ANSIColor(134)          // ANSI256 by number
```

Named ANSI 16: `Black`, `Red`, `Green`, `Yellow`, `Blue`, `Magenta`, `Cyan`, `White`,
`BrightBlack` through `BrightWhite`.

### Color Utilities

```go
lipgloss.Darken(c, 0.5)                  // darken by 50%
lipgloss.Lighten(c, 0.35)                // lighten by 35%
lipgloss.Complementary(c)                // complementary color
lipgloss.Alpha(c, 0.5)                   // semi-transparent
lipgloss.Blend1D(steps, colors...)       // 1D gradient
lipgloss.Blend2D(w, h, angle, colors...) // 2D gradient
```

Useful for deriving theme variants from base colors:

```go
highlight := lipgloss.Lighten(baseColor, 0.2)
subdued := lipgloss.Darken(baseColor, 0.4)
errorBg := lipgloss.Darken(red, 0.6)
successFg := lipgloss.Lighten(green, 0.2)
```

### Adaptive Colors

```go
hasDark := lipgloss.HasDarkBackground(os.Stdin, os.Stdout)
ld := lipgloss.LightDark(hasDark)
fg := ld(lipgloss.Color("#333"), lipgloss.Color("#EEE"))
```

In Bubble Tea, detect via `tea.BackgroundColorMsg`, don't use `lipgloss.HasDarkBackground`:

```go
case tea.BackgroundColorMsg:
    ld := lipgloss.LightDark(msg.IsDark())
    m.theme = newTheme(ld)
```

Per-profile exact colors:

```go
complete := lipgloss.Complete(colorprofile.Detect(os.Stdout, os.Environ()))
c := complete(
    lipgloss.Color("1"),        // ANSI
    lipgloss.Color("124"),      // ANSI256
    lipgloss.Color("#ff34ac"),  // TrueColor
)
```

## Border

Built-in border types: `NormalBorder`, `RoundedBorder`, `ThickBorder`, `DoubleBorder`,
`BlockBorder`, `OuterHalfBlockBorder`, `InnerHalfBlockBorder`, `HiddenBorder`,
`MarkdownBorder`, `ASCIIBorder`.

```go
s.Border(lipgloss.RoundedBorder())
s.Border(lipgloss.NormalBorder(), true, false)  // top+bottom only
s.BorderStyle(lipgloss.RoundedBorder()).BorderTop(true).BorderLeft(false)
s.BorderForeground(lipgloss.Color("63"))
s.BorderTopForeground(c).BorderBackground(c)
```

Gradient borders (2+ colors required):

```go
s.BorderForegroundBlend(c1, c2, c1)  // wrap for seamless loop
```

If `BorderStyle()` is set without any side booleans, all 4 sides render. Setting any
side explicitly means only those render.

## Layout

### Join Blocks

```go
lipgloss.JoinHorizontal(lipgloss.Top, a, b, c)
lipgloss.JoinVertical(lipgloss.Center, a, b)
```

### Place in Whitespace

```go
lipgloss.Place(80, 30, lipgloss.Right, lipgloss.Bottom, content)
lipgloss.PlaceHorizontal(80, lipgloss.Center, content)
lipgloss.PlaceVertical(30, lipgloss.Bottom, content,
    lipgloss.WithWhitespaceStyle(lipgloss.NewStyle().Background(c)),
    lipgloss.WithWhitespaceChars("."),
)
```

### Measure

```go
w, h := lipgloss.Size(rendered)
w := lipgloss.Width(rendered)
h := lipgloss.Height(rendered)
```

### Wrap (preserves ANSI)

```go
lipgloss.Wrap(text, 40, " ")
```

### Compositor

Layer content at specific positions:

```go
a := lipgloss.NewLayer(content).X(4).Y(2).Z(1)
b := lipgloss.NewLayer(overlay).X(10).Y(5).Z(2)
lipgloss.NewCompositor(a, b).Render()
```

Useful for dialog overlays, floating panels, and backdrop effects.

### Canvas

`Canvas` is a fixed-size cell buffer. Compose any `uv.Drawable` onto it (including
`lipgloss.Layer`); each `Compose` draws in order, so later drawables paint on top.
Call `Render()` to get a styled string. Use `Clear` or `Resize` when reusing the
same buffer across frames.

```go
c := lipgloss.NewCanvas(80, 24)
c.Compose(lipgloss.NewLayer(background).X(0).Y(0).Z(0))
c.Compose(lipgloss.NewLayer(panel).X(4).Y(2).Z(1))
out := c.Render()
```

For hit testing and flattening a full layer tree in one step, prefer `Compositor`
above; use `Canvas` when you want direct control over the cell grid or to implement
custom drawables.

## Table

```go
import "charm.land/lipgloss/v2/table"

t := table.New().
    Headers("NAME", "AGE").
    Row("Alice", "30").
    Rows([][]string{{"Bob", "25"}}...).
    Border(lipgloss.RoundedBorder()).
    BorderStyle(lipgloss.NewStyle().Foreground(lipgloss.Color("99"))).
    BorderHeader(true).BorderColumn(true).BorderRow(false).
    Width(60).Height(20).Wrap(true).
    StyleFunc(func(row, col int) lipgloss.Style {
        if row == table.HeaderRow {  // HeaderRow == -1
            return lipgloss.NewStyle().Bold(true).Align(lipgloss.Center)
        }
        return lipgloss.NewStyle().Padding(0, 1)
    })
lipgloss.Println(t)
```

For custom data, implement the `table.Data` interface:

```go
type Data interface {
    At(row, cell int) string
    Rows() int
    Columns() int
}
```

Filtering: `table.NewFilter(data).Filter(func(row int) bool { ... })`.

## List

```go
import "charm.land/lipgloss/v2/list"

l := list.New("A", "B", "C")

// Nested
l := list.New("Fruits", list.New("Apple", "Banana"), "Veggies", list.New("Carrot"))

// Enumerators: Bullet (default), Arabic, Alphabet, Roman, Dash, Asterisk
l.Enumerator(list.Arabic)
l.EnumeratorStyle(lipgloss.NewStyle().Foreground(lipgloss.Color("99")).MarginRight(1))
l.ItemStyle(lipgloss.NewStyle().Foreground(lipgloss.Color("212")))

lipgloss.Println(l.String())
```

## Tree

```go
import "charm.land/lipgloss/v2/tree"

t := tree.Root("Project").
    Child("src", tree.Root("cmd").Child("main.go")).
    Child("README.md")

t.Enumerator(tree.RoundedEnumerator)
t.RootStyle(style).ItemStyle(style).EnumeratorStyle(style)
t.Width(40)

lipgloss.Println(t.String())
```

## Common Patterns

### Styled Card

```go
head := lipgloss.NewStyle().Bold(true).
    Foreground(lipgloss.Color("#FAFAFA")).
    Background(lipgloss.Color("#7D56F4")).
    Padding(0, 1).Width(w)
frame := lipgloss.NewStyle().Padding(1, 2).Width(w).
    Border(lipgloss.RoundedBorder()).
    BorderForeground(lipgloss.Color("#7D56F4"))

lipgloss.JoinVertical(lipgloss.Left, head.Render(title), frame.Render(body))
```

### Two-Column Layout

```go
col := lipgloss.NewStyle().Width(total / 2).Padding(1, 2)
return lipgloss.JoinHorizontal(lipgloss.Top, col.Render(left), col.Render(right))
```

### Adaptive Theme

```go
func NewTheme(hasDark bool) Theme {
    ld := lipgloss.LightDark(hasDark)
    return Theme{
        Primary: ld(lipgloss.Color("#5A56E0"), lipgloss.Color("#7571F9")),
        Subtle:  ld(lipgloss.Color("#999"), lipgloss.Color("#666")),
    }
}
```

### Alternating-Row Table

```go
t := table.New().Headers(headers...).Rows(rows...).
    Border(lipgloss.RoundedBorder()).
    StyleFunc(func(row, col int) lipgloss.Style {
        base := lipgloss.NewStyle().Padding(0, 1)
        if row == table.HeaderRow {
            return base.Bold(true)
        }
        if row%2 == 0 {
            return base.Foreground(lipgloss.Color("245"))
        }
        return base.Foreground(lipgloss.Color("241"))
    })
```

## Gotchas

- `fmt.Println` instead of `lipgloss.Println` -- no color downsampling in standalone apps.
- Width includes padding and borders -- `Width(40)` is 40 total cells.
- `Color()` is a function in v2 -- returns `color.Color`, not a type literal.
- `Inherit()` skips margins/padding -- only text formatting and colors are inherited.
- v1/v2 import mixing -- v2 is `charm.land/lipgloss/v2`, not `github.com/charmbracelet/lipgloss`.
- `table.HeaderRow` is -1 -- not 0. Data rows start at 0.
- Border side defaults -- `BorderStyle()` alone renders all 4 sides. Setting any side
  explicitly means only those render.
- `Copy()` is deprecated; `Style` is a value type and setters return new styles, so
  assignment or chaining is preferred.
- Not accounting for borders in layout calculations -- subtract 2 from height for
  top+bottom border only if your border is a single cell per side, or use
  `GetVerticalBorderSize()` / the other Style getters under "Style getters (layout math)"
