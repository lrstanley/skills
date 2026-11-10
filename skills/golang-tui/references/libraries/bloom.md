# Layout, Layers, Input, and Motion with bloom

[bloom](https://github.com/lrstanley/bloom) (`github.com/lrstanley/bloom`) is the default
for laying out Bubble Tea v2 views in this skill. A view is described each frame as a tree
of nodes; bloom sizes and places them, composites layers (dialogs, dropdowns, toasts),
runs effects and animations, and routes mouse and focus input to the nodes they belong to.

It replaces most hand-written layout math, `lipgloss.JoinHorizontal` / `JoinVertical` /
`Place` trees, manual `lipgloss.Compositor` overlays, bubblezone-style hit testing, and
tick-driven animation state machines.

bloom is pre-1.0. This file stays high level on purpose. **Read the docs for the current
API before writing code**; do not rely on memory for node, option, or effect names.

## Documentation (read these, not this file, for details)

- Index of every page, as markdown: <https://bloomfx.dev/llms.txt>
- Everything in one file (large): <https://bloomfx.dev/llms-full.txt>
- Compact list of nodes and options: <https://bloomfx.dev/reference/options.md>
- Every effect: <https://bloomfx.dev/reference/effects.md>
- API reference: <https://pkg.go.dev/github.com/lrstanley/bloom> (plus `/anim`, `/fx`)
- Runnable examples: <https://github.com/lrstanley/bloom/tree/master/_examples>

Every docs page is also available as markdown at its path plus `.md`. Open the topic page
from `llms.txt` that matches the task (slots, responsive, scrolling, dialogs, mouse,
focus, transitions, ...) rather than loading everything.

The docs track the default branch, which can be ahead of the latest tag. If a documented
name or signature does not compile, check the version pinned in `go.mod` with
`go doc github.com/lrstanley/bloom <Symbol>` (or pkg.go.dev for that version), or upgrade.

## Requirements

Go 1.27+, Bubble Tea v2 (`charm.land/bubbletea/v2`), and Lip Gloss v2. Not usable with
Bubble Tea v1 (use bubblezone there for mouse zones).

## Packages

| Package | Covers |
| --- | --- |
| `bloom` | Layout nodes (rows, columns, grids, wraps, boxes, text, lists, scrolling, scrollbars), overlays and layers, mouse routing, focus, and the `Root` that renders the tree |
| `bloom/anim` | Animated values kept in the model: eased or spring values, presences for show/hide, sequences |
| `bloom/fx` | Cell effects used as transitions, layer backdrops, and feedback (fade, slide, dim, ...) |
| `bloom/on` | Mouse handlers attached to nodes (click, wheel, hover, drag, click outside) |
| `bloom/canvas`, `bloom/flex` | Low-level surfaces for custom effects, and the space-sharing math |

## Feature map

- **Sizing with slots**: the parent decides how children share space (fixed, natural,
  fill, weighted grow, percent, min/max). Components stay reusable because they do not
  know whether they are a sidebar or a full screen.
- **Responsive layouts**: collapse panels by priority when minimums do not fit, use
  percentages, and build layouts for the space a component is given.
- **Text and boxes**: styled/truncated text, Lip Gloss frames with titles or controls on
  the border, alignment, justification, and gaps. FIGlet text for banners.
- **Grids, wrapping, lists, scrolling**: equal-width grids, flowing wraps, virtualized
  lists that only build visible items, scroll containers, and scrollbars.
- **Layers**: overlays for dialogs and modals (backdrops, shadows, stacking), anchored
  dropdowns/popovers/tooltips, and toasts.
- **Input**: mouse handlers on the nodes they belong to, hover styles, drags, modal layers
  that capture input; keyboard focus with tab order, focus scopes, and the real terminal
  cursor placed relative to a node.
- **Motion**: animated values in the model, enter/exit transitions, automatic layout
  animation when slots move or resize, and feedback effects (shake, skeleton shimmer,
  rolling numbers, marquee, and more). Custom effects are possible.
- **Layout in `Update`**: `bloom.Solve` returns geometry without drawing, for sizing
  components that need their size up front and for paging.

## How it fits into Bubble Tea

bloom does not replace `Init` / `Update` / `View`; it lives inside them:

- Keep a `*bloom.Root` (from `bloom.New`) in the model. Return its `Init` command, pass
  every message to its `Update`, and return `ui.View(w, h, tree)` from `View`.
- Build the tree from the model in a `layout()` method so `View`, `Solve`, and tests share
  it. Nothing in the tree is kept between frames; state lives in the model.
- Your own components should implement `bloom.Layouter` (`Layout(ctx bloom.Context)
  bloom.Child`) and return nodes, so their IDs, handlers, focus, and animations stay part
  of the tree; keep a `View()` fallback. Any value with `View() string`, such as a Bubbles
  component or a simple leaf widget, can still be placed as is. See
  `references/child-model-composition.md`.
- Animations are values in the model, advanced by messages like other state.

Illustrative only; check the docs for current names and options.

```go
func (m *model) layout() bloom.Child {
	return bloom.Overlay(
		bloom.Column(
			bloom.Fill(bloom.Row(
				bloom.Fixed(24, m.sidebar).Collapsible(1),
				bloom.Fill(bloom.Box(panel, m.viewport)).ID(paneReader).Min(40),
			)),
			m.statusbar,
		),
		bloom.Layer(m.dialog).
			Modal().
			Backdrop(fx.Dim{Amount: 0.5}).
			Presence(m.dialogAnim, fx.Fade{}),
	)
}

func (m *model) View() tea.View {
	return m.ui.View(m.width, m.height, m.layout())
}
```

## Bubbles and other sized components

Components such as viewport, list, table, and textarea decide what to render from their
own size. bloom picks those sizes during layout, so on `tea.WindowSizeMsg` (and after any
change that alters the layout, such as toggling a panel) call `bloom.Solve` on the same
tree, read the slot rectangle by ID, subtract the box style's frame size, and pass the
result to the component. Keep that in one method called from every place the layout can
change. See <https://bloomfx.dev/layout/bubbles-components.md>.

## Testing

- `bloom.Render(w, h, tree)` draws a tree to a string for golden/text checks.
- `bloom.Solve(w, h, tree)` returns geometry for size and position assertions, which are
  less brittle than comparing drawn output.
- Whole-program behavior (clicks, focus, animation, timing) goes through steep; see
  `references/libraries/steep.md`. Give animations a controllable clock, or wait for the
  end state, to keep tests deterministic.

## When to use

- Any multi-region screen: sidebars, split panes, headers/status bars, grids, dashboards.
- Dialogs, modals, dropdowns, popovers, tooltips, toasts.
- Mouse support, hover, or click targets; focus and tab navigation across controls.
- Transitions, animations, loading skeletons, or other visual effects.
- Scrolling content with scrollbars, or long lists that should only build visible rows.

## When not to use

- Bubble Tea v1 programs.
- Inline (non-fullscreen) output that is a single styled string; plain Lip Gloss is enough.
- Inside a small leaf component's own `View`, where one Lip Gloss style or a short join
  is clearer than a tree. The leaf can still be placed in a bloom layout by its parent.
- Libraries we do not own that already use another approach; follow their conventions.

## Gotchas

- Rebuild the tree every frame from the model; do not cache nodes in the model.
- Give nodes stable IDs where focus, layout animation, anchoring, or `Solve` lookups need
  them; use a typed ID per purpose.
- A slot rectangle from `Solve` includes the box frame; subtract
  `GetHorizontalFrameSize()` / `GetVerticalFrameSize()` before sizing the child.
- Pass every message to the root's `Update`, or hover, terminal colors, and layout
  animation stop working.
- Troubleshooting (blank screen, clicks not arriving or arriving twice, animations not
  moving, text not wrapping): <https://bloomfx.dev/resources/troubleshooting.md>.
- Migrating from bubblezone: <https://bloomfx.dev/resources/migrating-from-bubblezone.md>.
