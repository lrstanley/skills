# beeep

Desktop notifications and sounds for Go. Import: `github.com/gen2brain/beeep`

Use for notifying the user when the TUI is in the background -- long-running operations
completing, critical errors, or attention-required events.

## Notifications

```go
import "github.com/gen2brain/beeep"

func notifyCmd(title, message string) tea.Cmd {
    return func() tea.Msg {
        _ = beeep.Notify(title, message, "")
        return nil
    }
}
```

The third argument is an icon path, embedded image bytes, or similar (empty string or
`nil` for system default; see beeep docs for your version).

## Application name

Set `beeep.AppName` once at startup (before any `Notify` or `Alert` call) so the OS
shows the correct sender name in the notification center. A typical place is the
constructor that builds your notification helper or in `main` before the first send:

```go
beeep.AppName = "MyTUI"
```

## Alerts

Alerts display a dialog-style notification on supported platforms:

```go
func alertCmd(title, message string) tea.Cmd {
    return func() tea.Msg {
        _ = beeep.Alert(title, message, "")
        return nil
    }
}
```

## Beep Sound

```go
func beepCmd() tea.Cmd {
    return func() tea.Msg {
        _ = beeep.Beep(beeep.DefaultFreq, beeep.DefaultDuration)
        return nil
    }
}
```

## Backend abstraction (policy vs transport)

Real apps often separate **when** to notify (focus, user prefs, feature flags) from
**how** to send. A small `Backend` interface keeps implementations limited to calling
`beeep`, while callers decide whether to invoke them.

```go
import "github.com/gen2brain/beeep"

type Notification struct {
    Title   string
    Message string
}

type Backend interface {
    Send(n Notification) error
}

// NativeBackend wraps beeep.Notify; use NoopBackend when notifications are off.
type NativeBackend struct {
    icon       any
    notifyFunc func(title, message string, icon any) error
}

func NewNativeBackend(icon any) *NativeBackend {
    beeep.AppName = "MyTUI"
    return &NativeBackend{
        icon:       icon,
        notifyFunc: beeep.Notify,
    }
}

func (b *NativeBackend) Send(n Notification) error {
    return b.notifyFunc(n.Title, n.Message, b.icon)
}

func (b *NativeBackend) SetNotifyFunc(fn func(title, message string, icon any) error) {
    b.notifyFunc = fn
}

func (b *NativeBackend) ResetNotifyFunc() {
    b.notifyFunc = beeep.Notify
}

type NoopBackend struct{}

func (NoopBackend) Send(_ Notification) error { return nil }
```

Use `NoopBackend` in headless CI, when the user disables notifications, or on
platforms where you skip desktop alerts. Keeps `Update` logic free of `if notify`
sprawl by selecting the backend at init time.

Optional: log inside `Send` with `log/slog` or your logger so failures from a missing
`notify-send` or OS permissions show up in diagnostics without surfacing raw errors
to the end user.

## Usage in Bubble Tea

Always wrap beeep calls in a `tea.Cmd`. Never call them directly in Update.

```go
func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case operationCompleteMsg:
        return m, tea.Batch(
            notifyCmd("Done", fmt.Sprintf("Operation %s completed", msg.name)),
            m.refreshData(),
        )
    case criticalErrorMsg:
        return m, tea.Batch(
            alertCmd("Error", msg.err.Error()),
            beepCmd(),
        )
    }
    return m, nil
}
```

## Conditional Notifications

Only notify when the terminal is not focused. Use `tea.FocusMsg`/`tea.BlurMsg` to
track focus state:

```go
type model struct {
    focused bool
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg.(type) {
    case tea.FocusMsg:
        m.focused = true
    case tea.BlurMsg:
        m.focused = false
    case operationCompleteMsg:
        var cmds []tea.Cmd
        cmds = append(cmds, m.refreshData())
        if !m.focused {
            cmds = append(cmds, notifyCmd("Done", "Operation completed"))
        }
        return m, tea.Batch(cmds...)
    }
    return m, nil
}
```

Enable focus reporting in View:

```go
func (m model) View() tea.View {
    v := tea.NewView(m.render())
    v.ReportFocus = true
    return v
}
```

## Platform Notes

- **macOS**: Uses native notification center. Works out of the box.
- **Linux**: Requires `notify-send` (libnotify) for notifications. Sound uses
  `paplay` or `aplay` if available.
- **Windows**: Uses native toast notifications.

Errors from beeep are safe to ignore. If the notification system is unavailable, the
function returns an error but the TUI continues normally.

## When to Use

- Background task completed while user is in another window
- Critical error requiring immediate attention
- Timer or countdown expired

## When Not to Use

- Routine UI feedback (use status bar messages instead)
- Every keystroke or navigation action
- Non-critical informational messages
