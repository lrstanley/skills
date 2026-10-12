# Clipboard

## Writing to Clipboard

Use a dual approach: OSC 52 (terminal-level) as primary, native clipboard as fallback.

### OSC 52

`tea.SetClipboard(content)` sends an OSC 52 sequence to the terminal. This works
without external tools but is not supported by all terminals (notably older versions
of gnome-terminal, some SSH sessions).

### Native Clipboard Fallback

`github.com/atotto/clipboard` uses platform-native clipboard access:

- macOS: `pbcopy`
- Linux: `xclip` or `xsel` (must be installed)
- Windows: native API

If `xclip`/`xsel` are not installed on Linux, `clipboard.WriteAll` returns an error.
Ignore it silently since OSC 52 may have succeeded.

### Dual Write Pattern

Try both methods and show a status message:

```go
import (
    "time"

    tea "charm.land/bubbletea/v2"
    "github.com/atotto/clipboard"
)

func SetClipboard(content string) tea.Cmd {
    return tea.Sequence(
        tea.SetClipboard(content),
        func() tea.Msg {
            _ = clipboard.WriteAll(content)
            return nil
        },
        sendStatus("copied to clipboard", statusInfo, 1*time.Second),
    )
}
```

`tea.Sequence` runs commands in order. The OSC 52 write happens first (fastest path),
then the native fallback, then the status notification.

### Usage in Update

```go
case tea.KeyPressMsg:
    if key.Matches(msg, types.KeyCopy) {
        content := m.selectedItem().Value
        return m, SetClipboard(content)
    }
```

## Reading from Clipboard

For paste functionality, `github.com/aymanbagabas/go-nativeclipboard` provides
cross-platform clipboard reading:

```go
import "github.com/aymanbagabas/go-nativeclipboard"

type clipboardReadMsg struct {
    content string
    err     error
}

func readClipboard() tea.Cmd {
    return func() tea.Msg {
        content, err := nativeclipboard.Read()
        return clipboardReadMsg{content: content, err: err}
    }
}
```

Bubble Tea also provides `tea.ReadClipboard` which uses OSC 52 to read. However,
terminal support for reading is even more limited than writing.

## Status Message Helper

Show temporary status messages after clipboard operations:

```go
type statusLevel int

const (
    statusInfo statusLevel = iota
    statusSuccess
    statusError
)

type statusMsg struct {
    text    string
    level   statusLevel
    timeout time.Duration
}

func sendStatus(text string, level statusLevel, timeout time.Duration) tea.Cmd {
    return func() tea.Msg {
        return statusMsg{text: text, level: level, timeout: timeout}
    }
}
```

## When to Use Each Method

| Method | Pros | Cons |
| --- | --- | --- |
| OSC 52 (`tea.SetClipboard`) | No external deps, works over SSH | Not all terminals support it |
| atotto/clipboard | Wide platform support | Needs xclip/xsel on Linux |
| Dual approach | Best coverage | Slightly more complex |

The dual approach covers the widest range of environments. The silent failure on
`clipboard.WriteAll` error means users with OSC 52 support but without xclip still
get working clipboard functionality.
