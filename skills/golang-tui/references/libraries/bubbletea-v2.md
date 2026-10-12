# Bubble Tea v2

Build terminal UIs in Go using the Elm Architecture. Import: `tea "charm.land/bubbletea/v2"`

## Quick Start

```go
package main

import (
    "fmt"
    "os"

    tea "charm.land/bubbletea/v2"
)

type model struct{ count int }

func (m model) Init() tea.Cmd { return nil }

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.KeyPressMsg:
        switch msg.String() {
        case "q", "ctrl+c":
            return m, tea.Quit
        case "up", "k":
            m.count++
        case "down", "j":
            m.count--
        }
    }
    return m, nil
}

func (m model) View() tea.View {
    return tea.NewView(fmt.Sprintf("Count: %d\n\nup/down to change, q to quit\n", m.count))
}

func main() {
    if _, err := tea.NewProgram(model{}).Run(); err != nil {
        fmt.Fprintln(os.Stderr, err)
        os.Exit(1)
    }
}
```

## The Elm Architecture

Bubble Tea follows a unidirectional data flow:

1. **Model** holds all application state
2. **Update** receives messages, returns updated model & optional command
3. **View** renders the model (called after every Update)
4. **Commands** perform async I/O and return messages back to Update

The runtime owns the loop. Never mutate state outside Update.

## tea.Model Interface

```go
type Model interface {
    Init() Cmd
    Update(Msg) (Model, Cmd)
    View() View
}
```

Only the root model implements `tea.Model`. Child components return their own concrete
type from Update (not `tea.Model`), since they are embedded fields, not standalone programs.

## tea.Cmd and tea.Msg

```go
type Msg = any
type Cmd func() Msg
```

A `Cmd` is a function the runtime executes asynchronously. It performs I/O and returns
a `Msg`. Return `nil` for no command.

## tea.View

```go
v := tea.NewView("Hello, World!")

v.AltScreen = true
v.MouseMode = tea.MouseModeCellMotion
v.ReportFocus = true
v.Cursor = tea.NewCursor(x, y)
v.WindowTitle = "My App"
v.BackgroundColor = someColor
v.KeyboardEnhancements.ReportEventTypes = true
```

## Program

```go
p := tea.NewProgram(model{}, opts...)
m, err := p.Run()
p.Send(msg) // thread-safe, from outside the program
p.Quit()    // quit from outside
p.Kill()    // force kill
p.Wait()    // block until shutdown
```

### Program Options

```go
tea.WithContext(ctx)
tea.WithInput(reader)
tea.WithOutput(writer)
tea.WithFilter(func(Model, Msg) Msg)
tea.WithFPS(fps)                        // default 60, max 120
tea.WithEnvironment([]string)           // custom env vars (SSH)
tea.WithWindowSize(w, h)                // initial size (testing)
tea.WithColorProfile(profile)           // force color profile
tea.WithoutRenderer()                   // no TUI rendering
tea.WithoutSignalHandler()
tea.WithoutCatchPanics()
```

## Built-in Messages

| Message | When |
| --- | --- |
| `tea.KeyPressMsg` | Key pressed |
| `tea.KeyReleaseMsg` | Key released (needs keyboard enhancements) |
| `tea.WindowSizeMsg` | Terminal resized (also sent on startup) |
| `tea.MouseClickMsg` | Mouse click |
| `tea.MouseReleaseMsg` | Mouse button released |
| `tea.MouseWheelMsg` | Scroll wheel |
| `tea.MouseMotionMsg` | Mouse moved (AllMotion mode) |
| `tea.FocusMsg` | Terminal gained focus (needs `ReportFocus`) |
| `tea.BlurMsg` | Terminal lost focus |
| `tea.PasteMsg` | Bracketed paste |
| `tea.ColorProfileMsg` | Terminal color profile on startup |
| `tea.BackgroundColorMsg` | Response to `RequestBackgroundColor` |

## Built-in Commands

| Command | Effect |
| --- | --- |
| `tea.Quit` | Exit the program |
| `tea.Suspend` | Suspend (ctrl+z) |
| `tea.Interrupt` | Interrupt (returns `ErrInterrupted`) |
| `tea.ClearScreen` | Clear terminal |
| `tea.Batch(cmds...)` | Run commands concurrently |
| `tea.Sequence(cmds...)` | Run commands in order |
| `tea.Every(dur, fn)` | Tick synced with system clock |
| `tea.Tick(dur, fn)` | Tick from invocation time |
| `tea.Println(args...)` | Print above TUI (persists across renders) |
| `tea.Printf(tmpl, args...)` | Printf above TUI |
| `tea.SetClipboard(s)` | Set system clipboard (OSC 52) |
| `tea.ReadClipboard` | Read system clipboard |
| `tea.RequestWindowSize` | Query current window size |
| `tea.RequestBackgroundColor` | Query terminal background color |
| `tea.ExecProcess(cmd, callback)` | Run external process (editor) |
| `tea.Raw(seq)` | Send raw escape sequence |

## Key Handling

```go
case tea.KeyPressMsg:
    switch msg.String() {
    case "ctrl+c", "q":
        return m, tea.Quit
    case "up", "k":
        m.cursor--
    case "enter", "space":
        m.selected = m.cursor
    case "ctrl+s":
        return m, m.save()
    }
```

Type-safe matching with the Key struct:

```go
case tea.KeyPressMsg:
    key := msg.Key()
    switch key.Code {
    case tea.KeyEnter:
        // ...
    case tea.KeyTab:
        // ...
    case tea.KeyEsc:
        // ...
    }
    // key.Mod for modifiers: tea.ModCtrl, tea.ModAlt, tea.ModShift
    // key.Text for printable characters
```

Prefer `key.Matches` with centralized bindings over raw string comparison.
See `references/keymaps.md` for the recommended pattern.

## Mouse Handling

Enable mouse in View, handle events in Update:

```go
func (m model) View() tea.View {
    v := tea.NewView(m.render())
    v.MouseMode = tea.MouseModeCellMotion
    return v
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.MouseClickMsg:
        if msg.Button == tea.MouseLeft {
            m.handleClick(msg.X, msg.Y)
        }
    case tea.MouseWheelMsg:
        if msg.Button == tea.MouseWheelUp {
            m.scrollUp()
        }
    }
    return m, nil
}
```

## Common Patterns

### Async I/O

Define a custom message type. Write a command that performs I/O and returns it.

```go
type fetchResultMsg struct {
    data []byte
    err  error
}

func fetchData(url string) tea.Cmd {
    return func() tea.Msg {
        resp, err := http.Get(url)
        if err != nil {
            return fetchResultMsg{err: err}
        }
        defer resp.Body.Close()
        data, err := io.ReadAll(resp.Body)
        return fetchResultMsg{data: data, err: err}
    }
}

func (m model) Init() tea.Cmd {
    return fetchData("https://api.example.com/items")
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case fetchResultMsg:
        if msg.err != nil {
            m.err = msg.err
            return m, nil
        }
        m.data = msg.data
    }
    return m, nil
}
```

### Ticking and Timers

`tea.Tick` fires once. Re-dispatch in Update to keep ticking.

```go
type tickMsg time.Time

func doTick() tea.Cmd {
    return tea.Tick(time.Second, func(t time.Time) tea.Msg {
        return tickMsg(t)
    })
}

func (m model) Init() tea.Cmd { return doTick() }

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg.(type) {
    case tickMsg:
        m.elapsed++
        return m, doTick()
    }
    return m, nil
}
```

`tea.Every` syncs with the system clock. `tea.Tick` starts from
invocation.

### Composing Child Components

Parent delegates messages to children and collects their commands.

```go
type model struct {
    spinner spinner.Model
    input   textinput.Model
}

func (m model) Init() tea.Cmd {
    return tea.Batch(m.spinner.Tick, m.input.Focus())
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    var cmds []tea.Cmd
    var cmd tea.Cmd

    m.spinner, cmd = m.spinner.Update(msg)
    cmds = append(cmds, cmd)

    m.input, cmd = m.input.Update(msg)
    cmds = append(cmds, cmd)

    return m, tea.Batch(cmds...)
}

func (m model) View() tea.View {
    return tea.NewView(m.spinner.View() + "\n" + m.input.View())
}
```

### External Messages via Channel

Use a channel-based command for subscription-like behavior:

```go
func waitForActivity(sub chan resultMsg) tea.Cmd {
    return func() tea.Msg {
        return <-sub
    }
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case resultMsg:
        m.results = append(m.results, msg)
        return m, waitForActivity(m.sub)
    }
    return m, nil
}
```

For concurrent-safe external messages (messages sent from outside of the program): `p.Send(msg)`.

### Fullscreen with Alt Screen

```go
func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.WindowSizeMsg:
        m.width = msg.Width
        m.height = msg.Height
    }
    return m, nil
}

func (m model) View() tea.View {
    v := tea.NewView(
        fmt.Sprintf("Fullscreen app! Size: %dx%d", m.width, m.height),
    )
    v.AltScreen = true
    return v
}
```

## Common Mistakes

- Calling a Cmd instead of passing it -- `Init` returns `tea.Cmd`, not `tea.Msg`.
- Mutating the model outside Update -- Use `p.Send()` or channel-based commands to communicate from goroutines.
- Not handling WindowSizeMsg -- Sent on startup and every resize. Store dimensions for layout math.
- Using fmt.Println -- Stdout is owned by the TUI. Use `tea.Println()` for persistent output, `log/slog` or `tea.LogToFile` for debug logging.
- Blocking in Update -- Any I/O (HTTP, file reads, sleeps) belongs in a Cmd.
- Not handling ctrl+c -- Always match `ctrl+c` and return `tea.Quit`.
