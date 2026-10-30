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

## Filter by Hue and Tone

Built-in tints have a hue (computed from the ANSI palette) and an optional tone (muted, retro,
and so on). An empty tone means uncategorized.

```go
blues := tint.NewRegistry(nil, tint.TintsByHue(tint.HueBlue)...)
for _, t := range blues.TintsByTone(tint.ToneMuted) {
	fmt.Println(t.DisplayName)
}
```

`Registry` also has `TintsByHue`, `TintsByTone`, and `TintsByHueAndTone`. Colors
have `Darken(percent)` and `Lighten(percent)` helpers (and package-level `tint.Darken`/`tint.Lighten`
for any `color.Color`).

## React to Changes

`Subscribe` is called when a tint is added, replaced, or removed, or when the current tint
changes. Listen for `CurrentChanged` to rebuild styles; forward it to your program with `p.Send`.

```go
cancel := tint.Subscribe(func(ev tint.Event) {
	if ev.Kind == tint.CurrentChanged {
		p.Send(rebuildStylesMsg{})
	}
})
defer cancel()
```

The callback runs synchronously on the goroutine that made the change, so keep it fast. Subscriptions
belong to a registry: if you replace `tint.DefaultRegistry`, subscribe again.

## Follow the Terminal's Theme

A `tint.Source` supplies tints from outside bubbletint, added with `tint.Attach`. Sources are opt-in
and live in their own module (`github.com/lrstanley/bubbletint/sources/v2/...`: `kitty`, `ghostty`,
`alacritty`, `foot`, `windowsterminal`, `xresources`, `itermcolors`, or `terminal` to auto-pick).

```go
src, err := terminal.Detect() // github.com/lrstanley/bubbletint/sources/v2/terminal
if err == nil {
	detach, err := tint.Attach(ctx, src)
	// [...]
}
```

Source tint IDs are prefixed with the source name (e.g. `kitty:current`). By default the registry
follows the source and updates when the user changes their theme; use `tint.WithFollow(false)` to only
register tints. Check `errors.Is(err, tint.ErrNotFound)` for unsupported terminals.

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

## Glamour Integration

Build a Glamour stylesheet from the current tint (code blocks use the same palette roles as chromatint):

```go
import (
	"charm.land/glamour/v2"
	"github.com/lrstanley/bubbletint/glamourtint/v2"
)

renderer, err := glamour.NewTermRenderer(
	glamour.WithStyles(glamourtint.StyleConfig(tint.Current())),
	glamour.WithWordWrap(80),
)
```
