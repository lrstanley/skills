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

## VHS for Demo Recording

[VHS](https://github.com/charmbracelet/vhs) records terminal sessions as GIFs using
a tape file format:

```bash
go run github.com/charmbracelet/vhs@latest demo.tape
```

Example `demo.tape`:

```vhs
Output tmp/demo.gif
Set FontSize 14
Set Width 1200
Set Height 600

Type "myapp"
Enter
Sleep 2s
Type "j"
Sleep 500ms
Type "j"
Sleep 500ms
Enter
Sleep 2s
Type "q"
```

Useful for:

- README demo GIFs
- Reproducible (but temporary) visual regression testing
- Bug report screenshots

### Taskfile Integration

```yaml
tape:
  desc: record demo GIFs
  deps: [build]
  cmds:
    - mkdir -p tmp/
    - go run github.com/charmbracelet/vhs@latest demo.tape
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
| Layout overflow | Not accounting for borders | Subtract 2 from height for top+bottom border or use `<style>.GetVerticalBorderSize()` |
| Misaligned panels | Text wrapping in bordered panels | Truncate all text to `panelWidth - 4` |
