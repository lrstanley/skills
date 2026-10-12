# Terminal Standards

## Environment Variables

### TERM

Identifies the terminal type. Common values:

- `xterm-256color` -- 256-color capable
- `xterm-color` -- basic 16-color
- `screen-256color` -- tmux/screen with 256 colors
- `dumb` -- no capabilities

### COLORTERM

Indicates extended color support:

- `truecolor` or `24bit` -- TrueColor (16M colors)
- Not set -- fall back to TERM-based detection

## Color Profiles

`github.com/charmbracelet/colorprofile` detects terminal color capabilities:

```go
import "github.com/charmbracelet/colorprofile"

profile := colorprofile.Detect(os.Stdout, os.Environ()) // Not needed with bubbletea.
```

Profile constants (ordered by capability):

- `colorprofile.ASCII` -- no color support
- `colorprofile.ANSI` -- 16 colors (basic)
- `colorprofile.ANSI256` -- 256 colors
- `colorprofile.TrueColor` -- 16 million colors

## Bubble Tea Integration

### tea.ColorProfileMsg

Sent once on startup with the detected terminal color profile:

```go
case tea.ColorProfileMsg:
    m.profile = msg.Profile
    // Recalculate theme based on the new profile if you want custom downsampling logic.
    cmd := styles.Theme.Update(msg)
    return m, cmd
```

### tea.BackgroundColorMsg

Sent in response to `tea.RequestBackgroundColor`. Reports whether the terminal
background is dark or light:

```go
func (m model) Init() tea.Cmd {
    return tea.Batch(
        tea.RequestBackgroundColor,
        // ...
    )
}

case tea.BackgroundColorMsg:
    m.hasDarkBg = msg.IsDark()
    cmd := styles.Theme.Update(msg)
    return m, cmd
```

## Automatic Color Downsampling

lipgloss automatically downsample colors to match terminal capabilities:

- In Bubble Tea: the runtime handles downsampling
- Standalone: use `lipgloss.Println` (not `fmt.Println`) for auto downsampling

TrueColor `#FF5733` automatically becomes the nearest ANSI256 or ANSI 16 color
when the terminal does not support higher depths.

## Alt Screen

```go
func (m model) View() tea.View {
    v := tea.NewView(m.render())
    v.AltScreen = true
    return v
}
```

The alt screen provides a clean, full-screen scrollback-free canvas. Toggle
dynamically by changing the `AltScreen` field based on application state.

## OSC Sequences

Operating System Command sequences communicate with the terminal emulator. Some examples:

- **OSC 52** -- Set clipboard content. Used by `tea.SetClipboard(s)`.
- **OSC 10/11** -- Query foreground/background colors. Used by `tea.RequestBackgroundColor`.
- **OSC 2** -- Set window title. Used by `tea.View.WindowTitle`.

These are handled by Bubble Tea's built-in commands. Do not send raw OSC sequences
unless you need terminal-specific features not covered by the API.

## Bracketed Paste

Bracketed paste lets the terminal wrap pasted text so applications can treat it as
one unit instead of many keypresses. The terminal enables mode `2004` (CSI
`?2004h`), wraps pasted bytes between `ESC[200~` and `ESC[201~`, then disables the
mode when appropriate.

**Bubble Tea:** The runtime enables bracketed paste by default. Handle `tea.PasteMsg`
(`.Content` holds the pasted text). Optional `tea.PasteStartMsg` and `tea.PasteEndMsg`
bracket the paste if you need boundary hooks. Set `v.DisableBracketedPasteMode = true`
on the View to turn the feature off for that frame.

**Low-level sequences:** `github.com/charmbracelet/x/ansi` defines `SetModeBracketedPaste`,
`ResetModeBracketedPaste`, and the paste delimiter constants `BracketedPasteStart` /
`BracketedPasteEnd` (the `200~` / `201~` wrappers). Prefer Bubble Tea messages over
parsing delimiters yourself.

## Keyboard Enhancements

**Kitty keyboard protocol:** Terminals that implement it can report richer key events
(disambiguation, release events, repeat). `github.com/charmbracelet/x/ansi` exposes
helpers such as `RequestKittyKeyboard`, `KittyKeyboard(flags, mode)`, `PushKittyKeyboard`,
`PopKittyKeyboard`, and `DisableKittyKeyboard`. See the upstream spec linked from
`kitty.go` in that module.

**Bubble Tea:** Request enhanced behavior on the View:

```go
v.KeyboardEnhancements.ReportEventTypes = true
```

When supported, you get `tea.KeyboardEnhancementsMsg` (check `SupportsEventTypes()` and
related helpers), `tea.KeyReleaseMsg`, and `tea.KeyPressMsg` with `Key.IsRepeat` for
auto-repeat. Not every terminal implements the full set; always handle the baseline
`tea.KeyPressMsg` paths.

## Progress Indicators

### OSC 9 taskbar / shell progress (Windows Terminal and similar)

Some terminals show progress in the window or tab using OSC `9;4` sequences.
`github.com/charmbracelet/x/ansi` provides `SetProgressBar`, `SetErrorProgressBar`,
`SetWarningProgressBar`, `SetIndeterminateProgressBar`, and `ResetProgressBar`.
Bubble Tea also provides `view.ProgressBar` for in-TUI progress bars.

### In-app progress bar (Bubbles)

For a bar drawn inside your Bubble Tea layout, use `charm.land/bubbles/v2/progress`
(animated or static `ViewAs`). See `references/libraries/bubbles-v2.md`.

## Images and Raster Output

Sixel, Kitty graphics, iTerm2 inline images, and unicode mosaic rendering are covered
in `references/images.md` (package map, Bubble Tea embedding, and code examples).

## Testing with Reduced Color Depth

Add Taskfile/Makefile tasks that force reduced color to verify fallbacks work.
Taskfile example:

```yaml
debug:basic:
  desc: run with reduced color depth
  interactive: true
  cmds:
    - TERM="xterm-color" COLORTERM="xterm-color" go run
```

This causes `colorprofile.Detect` to report `ANSI` instead of TrueColor, exercising
your fallback color paths.

### What to Test

- All colors render as readable ANSI basic colors
- Layout is unaffected by color depth changes
- No TrueColor escape sequences leak into ANSI-only output (can occur with pre-computed state/styles)

## Summary

| Feature | Controlled By | Bubble Tea / Charm notes |
| --- | --- | --- |
| Color depth | TERM, COLORTERM | `tea.ColorProfileMsg` |
| Dark/light | Background query | `tea.BackgroundColorMsg` |
| Alt screen | View property | `view.AltScreen = true` |
| Window title | View property | `view.WindowTitle = "..."` |
| Clipboard | OSC 52 | `tea.SetClipboard(s)` |
| Mouse | View property | `view.MouseMode = ...` |
| Focus events | View property | `view.ReportFocus = true` |
| Bracketed paste | Terminal mode 2004 | `tea.PasteMsg`, optional `DisableBracketedPasteMode`; `ansi.SetModeBracketedPaste` |
| Keyboard enhancements | Kitty protocol, terminal | `view.KeyboardEnhancements`, `tea.KeyboardEnhancementsMsg`, `KeyReleaseMsg`; `ansi.KittyKeyboard` |
| OSC progress | Terminal (OSC 9;4) | `ansi.SetProgressBar` and `view.ProgressBar` |
| Images, sixel, Kitty, iTerm2, mosaic | Terminal protocol | `references/images.md` |
