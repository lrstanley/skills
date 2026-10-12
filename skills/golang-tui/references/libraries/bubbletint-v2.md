# Bubbletint v2

Pre-made terminal color themes for Go TUI applications. Import: `github.com/lrstanley/bubbletint/v2`

bubbletint exposes each theme as a `Tint` struct with standard terminal colors (Fg, Bg,
Black, Red, Green, bright variants, and so on) as `color.Color` values for `lipgloss`
and similar libraries.

Important `Tint` fields:

- `DisplayName` and `ID`: human-readable and normalized theme names.
- `Dark`: whether the background is considered dark.
- `Fg` and `Bg`: recommended default foreground and background colors.
- `SelectionBg` and `Cursor`: optional colors for selections and cursor rendering.
- Standard colors: `Black`, `Red`, `Green`, `Yellow`, `Blue`, `Purple`, `Cyan`,
  and `White`.
- Bright colors: `BrightBlack`, `BrightRed`, `BrightGreen`, `BrightYellow`,
  `BrightBlue`, `BrightPurple`, `BrightCyan`, and `BrightWhite`.
  These are palette slots for the tint, so `Black`, `Red`, or `Green` are not
  guaranteed to be literally black, red, or green in every color scheme. Think
  of them semantically: choosing `Red` for danger or errors lets that intent
  adapt to each color scheme.
- `CreditSources`: optional attribution for the theme source.

## Basic Usage

Default registry (all built-in tints), then read the active tint with `Current()`:

```go
import (
	"github.com/charmbracelet/lipgloss/v2"
	tint "github.com/lrstanley/bubbletint/v2"
)

tint.NewDefaultRegistry()
tint.SetTint(tint.TintDraculaPlus)
// tint.SetTintID("dracula_plus")

style := lipgloss.NewStyle().
	Foreground(tint.Current().Fg).
	Background(tint.Current().BrightGreen)
```

Use a single tint without a registry:

```go
var theme = tint.TintDraculaPlus
style := lipgloss.NewStyle().
	Foreground(theme.Fg).
	Background(theme.BrightGreen)
```

## Tint Registry

The registry holds a set of tints and provides cycling between them:

```go
import tint "github.com/lrstanley/bubbletint/v2"

registry := tint.NewRegistry(
	tint.TintDjango, // First is the default tint.
	tint.TintAfterglow,
	tint.TintSpacedust,
	tint.TintCyberPunk2077,
	tint.TintSolarizedDarkPatched,
	tint.TintPencilDark,
)

current := registry.Current()   // returns the active `tint.Tint`
registry.NextTint()             // cycle forward
registry.PreviousTint()         // cycle backward
```

Register more tints after construction with `Register`, and call `SetTint` to pick the active one.

## Chromatint Integration

Export a chroma syntax highlighting style from the active tint:

```go
import (
	"github.com/alecthomas/chroma/v2"
	"github.com/lrstanley/bubbletint/chromatint/v2"
)

func (tc *ThemeConfig) set() {
	t := tc.registry.Current()
	if cs, err := chroma.NewStyle("myapp", chromatint.StyleEntry(t, false)); err == nil {
		tc.chroma = cs
	}
	// ... rest of color derivation
}
```

See `references/libraries/chroma-v2.md` for usage details.
