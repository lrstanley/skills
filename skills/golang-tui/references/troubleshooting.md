# Troubleshooting

## Debug Logging

### tea.LogToFile

Quick debug logging without any setup:

```go
func main() {
    if cli.Debug { // E.g. cli flag or env var.
        f, err := tea.LogToFile("debug.log", "debug")
        if err != nil {
            fmt.Fprintf(os.Stderr, "failed to set up logging: %v\n", err)
            os.Exit(1)
        }
        defer f.Close()
    }
    // [...]
}
```

### Structured Logging with `log/slog`

For production applications and/or those already using `log/slog`, use `log/slog` writing to a file:

```go
f, err := os.OpenFile(path, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o640)
if err != nil {
    // [...]
}
handler := slog.NewTextHandler(f, &slog.HandlerOptions{
    Level: slog.LevelDebug,
})
slog.SetDefault(slog.New(handler))
```

Never use `fmt.Println` or `log.Println` to stdout. The TUI renderer owns stdout.
Any writes to stdout corrupt the display.

## String Width Gotcha

ANSI escape sequences add invisible bytes to strings. Using `len()` gives wrong results:

```go
styled := lipgloss.NewStyle().Foreground(lipgloss.Color("205")).Render("hello")

len(styled)              // 23 (includes escape sequences)
ansi.StringWidth(styled) // 5 (visible characters only)
lipgloss.Width(styled)   // 5 (visible characters, but accounts for max length over multiple newlines)
```

Always use `ansi.StringWidth` or `lipgloss.Width` for:

- Layout calculations
- Truncation decisions
- Padding computations
- Any comparison to terminal width/height

## Reproducing and Inspecting a Running TUI

To see what a program actually draws, use the reel CLI from steep (see
`references/libraries/steep.md`) instead of guessing from code:

- **Agents** (and scripts): `reel session` starts the program in a detached terminal,
  sends keys, waits for text, and prints the screen as text, JSON, or a PNG still. Use it
  for programs without steep tests, including third-party libraries we are fixing.
  <https://getsteep.dev/cli/sessions.md>
- **Go tests**: a steep harness with failure recordings shows exactly what the screen
  looked like when a test failed; open the `.cast` in the
  [inspector](https://inspector.getsteep.dev/) to step through events.
- **Layout bugs with bloom**: `bloom.Solve` reports each node's rectangle, and the bloom
  troubleshooting page covers blank screens, double clicks, stuck animations, and
  wrapping: <https://bloomfx.dev/resources/troubleshooting.md>.

## Demo Recording

`reel run` executes [VHS](https://github.com/charmbracelet/vhs)-syntax tapes with its own
renderer (no browser or `ttyd`), so existing VHS tapes run as they are. Prefer it over
`vhs` for README GIFs and screenshots. Tape syntax and settings:
<https://getsteep.dev/cli/tapes.md>.

```bash
go run github.com/lrstanley/steep/cmd/reel@latest run demo.tape
```

`reel test` runs tapes as black-box tests with waits and golden files, which is useful
for non-Go programs; for Go programs, prefer steep tests.

### Taskfile Integration

```yaml
tape:
  desc: record demo GIFs
  deps: [build]
  cmds:
    - mkdir -p tmp/
    - go run github.com/lrstanley/steep/cmd/reel@latest run demo.tape
```

## pprof Integration

Embed pprof for runtime profiling behind a flag:

```go
import _ "net/http/pprof"

if flags.EnablePprof {
    go func() {
        slog.Info("pprof server starting on http://localhost:6060")
        http.ListenAndServe("localhost:6060", nil)
    }()
}
```

### Taskfile Profile Tasks

```yaml
profile:cpu:
  desc: CPU profile for 15 seconds
  cmds:
    - go tool pprof -http :6061 'http://127.0.0.1:6060/debug/pprof/profile?seconds=15'
profile:heap:
  desc: heap profile
  cmds:
    - go tool pprof -http :6061 'http://127.0.0.1:6060/debug/pprof/heap'
profile:allocs:
  desc: allocation profile
  cmds:
    - go tool pprof -http :6061 'http://127.0.0.1:6060/debug/pprof/allocs'
```

Run the app with `--enable-pprof`, then in another terminal run the profile task.

## Debugging Checklist

- **Check logs** -- Look at `debug.log` or slog output for errors
- **Verify WindowSizeMsg** -- Log width/height to confirm they are non-zero
- **Check color profile** -- Log the `ColorProfileMsg` value
- **Test with basic colors** -- Run `debug:basic` task to verify ANSI fallbacks
- **Check component focus** -- Log which component has focus
- **Benchmark View** -- Profile if rendering feels slow
- **Check for blocking** -- Any I/O or sleep in Update freezes the UI

## Gotchas

| Symptom | Likely Cause | Fix |
| --- | --- | --- |
| Blank screen on startup | Not handling `tea.WindowSizeMsg` | Always handle `WindowSizeMsg` in Update; set component dimensions |
| Frozen UI | Blocking I/O in `Update()` | Move I/O to `tea.Cmd` functions |
| Flickering | Excessive re-renders or slow View | Reduce `tea.WithFPS`, pre-compute in Update |
| Colors broken in tmux | tmux overrides TERM | Set `set -g default-terminal "tmux-256color"` in tmux.conf |
| Garbled output after crash | Raw mode not restored | Wrap program in panic handler, ensure `p.Kill()` on panic |
| Spinner not animating | Forgot to return `Tick` from Init | Return `m.spinner.Tick` from `Init()` |
| Input not working | Component not focused | Call `.Focus()` and use the returned `tea.Cmd` |
| Layout overflow | Not accounting for borders, or hand-computed widths | Lay out with bloom slots; otherwise use `<style>.GetVerticalFrameSize()` / `GetHorizontalFrameSize()` |
| Misaligned panels | Text wrapping in bordered panels | Use bloom `Text(...).Truncate()`, or truncate to the inner width (`panelWidth - style.GetHorizontalFrameSize()`) |
| Clicks hit the wrong item | Manual X/Y hit testing drifts from what was drawn | Attach `bloom/on` handlers to the nodes themselves |
| Behavior unclear from code | Not observing the real screen | Drive it with `reel session` or a steep test with failure recordings |
