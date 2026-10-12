# External process execution

Use `tea.ExecProcess` when the TUI must release the terminal to a child process,
wait for it to exit, then resume and handle the result in `Update` via a message
from the callback.

## When to use

- A subprocess should own the terminal until it finishes (pager, interactive
  tool, editor, full-screen helper)
- You need the exit `error` delivered as a `tea.Msg` after the process ends

## When not to use

- Work that should keep the TUI running without suspending the renderer (use a
  `tea.Cmd` that runs a goroutine and sends a custom message when done)
- Cases where you do not need Bubble Tea to hand off the terminal (evaluate
  whether `ExecProcess` is required)

## Core pattern

Build an `*exec.Cmd` with `os/exec`, pass it to `tea.ExecProcess`, and return a
message from the callback so `Update` can react:

```go
import (
    "os/exec"

    tea "charm.land/bubbletea/v2"
)

func runProcess(cmd *exec.Cmd) tea.Cmd {
    return tea.ExecProcess(cmd, func(err error) tea.Msg {
        return externalFinishedMsg{err: err}
    })
}

// Caller constructs the command, for example:
//   runProcess(exec.Command("less", path))
//   runProcess(exec.Command("git", "log", "-p"))
```

Handle `externalFinishedMsg` (or your named message) in `Update` like any other
message.

## Example: user editor via `x/editor`

Opening a file in the user's preferred editor is the same pattern: `x/editor`
builds the `*exec.Cmd` (`$EDITOR` resolution, platform defaults, and options such
as line numbers), and you still pass it to `tea.ExecProcess`:

```go
import (
    tea "charm.land/bubbletea/v2"
    "github.com/charmbracelet/x/editor"
)

func openEditor(path string) tea.Cmd {
    cmd, err := editor.Command("myapp", path)
    if err != nil {
        return func() tea.Msg { return editorFinishedMsg{err: err} }
    }
    return tea.ExecProcess(cmd, func(err error) tea.Msg {
        return editorFinishedMsg{err: err}
    })
}
```

Pass options like `editor.LineNumber(n)` or `editor.AtPosition(line, col)` when
the editor supports opening at a specific location.

## Related

- `references/libraries/bubbletea-v2.md` -- `tea.ExecProcess` in the command table
- `references/child-model-composition.md` -- wiring this into larger models
