# Testing Bubble Tea Applications

## teatest

`github.com/charmbracelet/x/exp/teatest/v2` provides integration testing for Bubble Tea
programs. It runs a real `tea.Program` with in-memory I/O, lets you send messages, and
reads output for assertions.

Use `NewTestModel`. The returned `*TestModel` wraps the program and exposes `Send`,
`Output`, `Quit`, `WaitFinished`, `FinalOutput`, `FinalModel`, and `Type`.

### Non-root models and components

`teatest` runs a full `tea.Program` with one root `tea.Model`. It does not currently
support using a non-root model (for example a subtree or standalone component) as the
program root. For testing those pieces, snapshot testing `View()` output is often the
most practical option today (golden files or go-snaps below), sometimes with a small
test harness that wires fixed dimensions and state.

### Basic Test

```go
package ui_test

import (
	"strings"
	"testing"
	"time"

	tea "charm.land/bubbletea/v2"
	"github.com/charmbracelet/colorprofile"
	"github.com/charmbracelet/x/exp/teatest/v2"
)

func TestApp(t *testing.T) {
	m := NewModel()
	tm := teatest.NewTestModel(
		t,
		m,
		teatest.WithInitialTermSize(80, 24),
		teatest.WithProgramOptions(
			tea.WithColorProfile(colorprofile.ASCII),
		),
	)

	teatest.WaitFor(t, tm.Output(), func(bts []byte) bool {
		return strings.Contains(string(bts), "Ready")
	}, teatest.WithDuration(3*time.Second))

	tm.Send(tea.KeyPressMsg{Code: tea.KeyEnter})

	teatest.WaitFor(t, tm.Output(), func(bts []byte) bool {
		return strings.Contains(string(bts), "Selected")
	})

	tm.Type("q")

	if err := tm.Quit(); err != nil {
		t.Fatal(err)
	}
	tm.WaitFinished(t, teatest.WithFinalTimeout(3*time.Second))
}
```

`WaitFor` takes an `io.Reader` (use `tm.Output()`), not the `*TestModel` itself. Optional
`teatest.WithDuration` and `teatest.WithCheckInterval` control timeouts and polling.

### Color profile

Prefer passing `tea.WithColorProfile` via `WithProgramOptions` so output is comparable across
machines. `colorprofile.ASCII` removes color escapes; `colorprofile.ANSI` keeps 16-color
output if you need slightly richer but still stable snapshots.

```go
tm := teatest.NewTestModel(
	t,
	m,
	teatest.WithInitialTermSize(80, 24),
	teatest.WithProgramOptions(
		tea.WithColorProfile(colorprofile.ASCII),
	),
)

tm.Send(someMsg)
```

### Sending messages and typing

```go
tm.Send(tea.WindowSizeMsg{Width: 80, Height: 24})
tm.Type("hello") // sends KeyPressMsg per rune

tm.Send(tea.KeyPressMsg{Code: tea.KeyEnter})
tm.Send(tea.KeyPressMsg{Code: 'j', Text: "j"})

tm.Send(myCustomMsg{data: "test"})
```

### Waiting for output

```go
teatest.WaitFor(t, tm.Output(), func(bts []byte) bool {
	return strings.Contains(string(bts), "expected output")
}, teatest.WithDuration(5*time.Second), teatest.WithCheckInterval(10*time.Millisecond))
```

### Finishing the program

- `tm.Quit()` requests shutdown (typical when the test drives exit).
- `tm.WaitFinished(t, teatest.WithFinalTimeout(...))` blocks until `Run` returns (use if
the app exits on its own).
- `tm.FinalOutput(t, opts...)` and `tm.FinalModel(t, opts...)` wait for completion
(with optional `teatest.WithFinalTimeout`) and return output or the final model.

`teatest.RequireEqualOutput` compares bytes to golden files (see below).

## Golden Files

`github.com/charmbracelet/x/exp/golden` compares output against saved golden files.
On first run (or when updating), it writes the file. On subsequent runs, it asserts
equality.

```go
import "github.com/charmbracelet/x/exp/golden"

func TestView(t *testing.T) {
	m := NewModel()
	m.width = 80
	m.height = 24

	got := m.View()
	golden.RequireEqual(t, []byte(got.String()))
}
```

Golden files are stored in `testdata/` next to the test file.

Update golden files by passing the `-update` flag (defined by `golden`):

```bash
go test -update ./...
```

## go-snaps (Alternative)

`github.com/gkampitakis/go-snaps` is an alternative snapshot testing library that
supports inline snapshots and multiple snapshots per test.

```go
import "github.com/gkampitakis/go-snaps/snaps"

func TestView(t *testing.T) {
	m := NewModel()
	m.width = 80
	m.height = 24

	snaps.MatchSnapshot(t, m.View().String())
}
```

Snapshot files live in `__snapshots__/` next to the test.

Update snapshots:

```bash
UPDATE_SNAPS=always go test ./...
```

### Taskfile Integration

```yaml
test:
  desc: run tests
  cmds:
    - go test -count 5 -p 3 {{ "{{" }} or .CLI_ARGS "./..." {{ "}}" }}
test:update:
  desc: run tests and update snapshots
  cmds:
    - UPDATE_SNAPS=always go test -count 2 -p 3 {{ "{{" }} or .CLI_ARGS "./..." {{ "}}" }}
```

## Do's

- Prefer `View()` snapshots (golden or go-snaps) for non-root models or components; use
  `teatest` for the root `tea.Program` only until the library gains non-root support
- Set color profile with `WithProgramOptions(tea.WithColorProfile(...))` for stable output
- Set size with `WithInitialTermSize` (default inside `NewTestModel` is 80x24 if you only
  pass program options)
- Use `WaitFor` with `tm.Output()` as the reader argument
- Use golden files or snapshots for view regression testing
- Keep `go test -count` > 1 to catch flaky timing-dependent tests
- Strip things like spinner frames from the output before comparing with snapshots, as they
  are time-dependent and inconsistent

## Don'ts

- Pass `WaitFor` the `*TestModel` instead of `tm.Output()`
- Run snapshot updates in CI unless that step is explicitly requested
