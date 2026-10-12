# Bubble Tea v2 Examples

The authoritative index of official Bubble Tea examples lives at
[charmbracelet/bubbletea/examples](https://github.com/charmbracelet/bubbletea/tree/main/examples).
This file summarizes each example and the patterns it demonstrates.

---

### Alt Screen Toggle

**Tree:** https://github.com/charmbracelet/bubbletea/tree/main/examples/altscreen-toggle

- Transitioning between alt screen and normal screen
- `tea.View.AltScreen` toggling

### Chat

**Tree:** https://github.com/charmbracelet/bubbletea/tree/main/examples/chat

- Multi-line `textarea` input
- Basic chat UI layout

### Composable Views

**Tree:** https://github.com/charmbracelet/bubbletea/tree/main/examples/composable-views

- Composing two bubble models (spinner + timer) in a single app
- Switching between composed views

### ISBN Book Form

**Tree:** https://github.com/charmbracelet/bubbletea/tree/main/examples/isbn-form

- Multi-step form with `textinput` bubbles
- Input validation

### Debounce

**Tree:** https://github.com/charmbracelet/bubbletea/tree/main/examples/debounce

- Throttling key presses
- Avoiding overloading the update loop

### Exec

**Tree:** https://github.com/charmbracelet/bubbletea/tree/main/examples/exec

- `tea.ExecProcess` to launch an external command (e.g. `$EDITOR`)
- Suspending/resuming the TUI

### Full Screen

**Tree:** https://github.com/charmbracelet/bubbletea/tree/main/examples/fullscreen

- Fullscreen TUI with alt screen

### Glamour

**Tree:** https://github.com/charmbracelet/bubbletea/tree/main/examples/glamour

- Rendering Markdown with Glamour inside a viewport bubble

### Help

**Tree:** https://github.com/charmbracelet/bubbletea/tree/main/examples/help

- `help` bubble integration
- `key.Binding` help text display

### HTTP

**Tree:** https://github.com/charmbracelet/bubbletea/tree/main/examples/http

- Making HTTP calls as `tea.Cmd`
- Async I/O pattern

### Default List

**Tree:** https://github.com/charmbracelet/bubbletea/tree/main/examples/list-default

- `list` bubble with default delegate

### Fancy List

**Tree:** https://github.com/charmbracelet/bubbletea/tree/main/examples/list-fancy

- `list` bubble with custom styling and delegate

### Simple List

**Tree:** https://github.com/charmbracelet/bubbletea/tree/main/examples/list-simple

- `list` bubble with compact, simplified appearance

### Mouse

**Tree:** https://github.com/charmbracelet/bubbletea/tree/main/examples/mouse

- Mouse event handling
- `tea.MouseClickMsg`, `tea.MouseWheelMsg`

### Package Manager

**Tree:** https://github.com/charmbracelet/bubbletea/tree/main/examples/package-manager

- `tea.Println` for persistent output above TUI

### Pager

**Tree:** https://github.com/charmbracelet/bubbletea/tree/main/examples/pager

- Simple pager (like `less`)
- `viewport` bubble usage

### Paginator

**Tree:** https://github.com/charmbracelet/bubbletea/tree/main/examples/paginator

- `paginator` bubble for paginated lists

### Pipe

**Tree:** https://github.com/charmbracelet/bubbletea/tree/main/examples/pipe

- Shell pipes for communicating with Bubble Tea apps
- `tea.WithInput` / `tea.WithOutput`

### Animated Progress

**Tree:** https://github.com/charmbracelet/bubbletea/tree/main/examples/progress-animated

- `progress` bubble with animated progression
- `progress.FrameMsg` handling

### Download Progress

**Tree:** https://github.com/charmbracelet/bubbletea/tree/main/examples/progress-download

- File download with `progress` bubble
- Combining I/O commands with progress updates

### Static Progress

**Tree:** https://github.com/charmbracelet/bubbletea/tree/main/examples/progress-static

- `progress.ViewAs` for static (non-animated) progress

### Real Time

**Tree:** https://github.com/charmbracelet/bubbletea/tree/main/examples/realtime

- Go channels for real-time communication with the TUI
- Channel-based subscription pattern

### Result

**Tree:** https://github.com/charmbracelet/bubbletea/tree/main/examples/result

- Choice menu with option selection
- Returning a result from the program

### Send Msg

**Tree:** https://github.com/charmbracelet/bubbletea/tree/main/examples/send-msg

- Custom `tea.Msg` types
- `p.Send()` from outside

### Sequence

**Tree:** https://github.com/charmbracelet/bubbletea/tree/main/examples/sequence

- `tea.Sequence` for ordered command execution

### Simple

**Tree:** https://github.com/charmbracelet/bubbletea/tree/main/examples/simple

- Minimal Bubble Tea application
- Basic Init/Update/View

### Spinner

**Tree:** https://github.com/charmbracelet/bubbletea/tree/main/examples/spinner

- `spinner` bubble usage

### Spinners

**Tree:** https://github.com/charmbracelet/bubbletea/tree/main/examples/spinners

- Multiple spinner types showcase

### Split Editors

**Tree:** https://github.com/charmbracelet/bubbletea/tree/main/examples/split-editors

- Multiple `textarea` bubbles
- Focus switching between editors

### Stop Watch

**Tree:** https://github.com/charmbracelet/bubbletea/tree/main/examples/stopwatch

- `stopwatch` bubble usage

### Table

**Tree:** https://github.com/charmbracelet/bubbletea/tree/main/examples/table

- `table` bubble for tabular data display

### Tabs

**Tree:** https://github.com/charmbracelet/bubbletea/tree/main/examples/tabs

- Tabbed navigation
- Lip Gloss styling for tab chrome

### Text Area

**Tree:** https://github.com/charmbracelet/bubbletea/tree/main/examples/textarea

- `textarea` bubble usage

### Text Input

**Tree:** https://github.com/charmbracelet/bubbletea/tree/main/examples/textinput

- `textinput` bubble usage

### Multiple Text Inputs

**Tree:** https://github.com/charmbracelet/bubbletea/tree/main/examples/textinputs

- Multiple `textinput` bubbles
- Focus switching and cursor mode

### Timer

**Tree:** https://github.com/charmbracelet/bubbletea/tree/main/examples/timer

- `timer` bubble usage

### TUI Daemon

**Tree:** https://github.com/charmbracelet/bubbletea/tree/main/examples/tui-daemon-combo

- Combined TUI + daemon mode
- Conditional TUI rendering

### Views

**Tree:** https://github.com/charmbracelet/bubbletea/tree/main/examples/views

- Multiple views with view switching
- State machine pattern
