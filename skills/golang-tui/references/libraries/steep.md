# Testing Bubble Tea Applications with steep

Use `github.com/lrstanley/x/charm/steep` for Bubble Tea integration tests,
component tests, view assertions, and snapshots. `steep` is the preferred
alternative to `github.com/charmbracelet/x/exp/teatest/v2`,
`github.com/charmbracelet/x/exp/golden`, and `github.com/gkampitakis/go-snaps`
for TUI testing in this skill.

`steep` runs models through the real Bubble Tea runtime, captures the latest
view, sends input, waits for output, observes messages, mutates state inside
`Update`, and writes snapshots under `testdata`.

Upstream reference: [steep README](https://github.com/lrstanley/x/tree/master/charm/steep).

## When to use

- Testing a full Bubble Tea root model that implements `tea.Model`.
- Testing a component model that has `View() string` plus an `Update` method.
- Waiting for rendered output after key presses, messages, commands, or async
  work.
- Asserting view content, ANSI-aware dimensions, observed messages, or snapshots.
- Replacing older `teatest`, `golden`, or `go-snaps` guidance in TUI tests.

## When not to use

- Pure functions that can be tested directly without a Bubble Tea runtime.
- Slow end-to-end tests that need a real terminal emulator or shell session.
- Visual protocol encoders where asserting stable byte-level invariants is
  clearer than snapshotting a large binary-heavy payload.

## Root model harness

Use `NewHarness` when the thing under test is the application root model.

```go
package ui

import (
	"fmt"
	"strings"
	"testing"

	tea "charm.land/bubbletea/v2"
	"github.com/lrstanley/x/charm/steep"
)

type openCommandMsg struct {
	Command string
}

type commandPalette struct {
	width, height int
	query         string
	commands      []string
	opened        []string
}

// [...]

func TestCommandPalette(t *testing.T) {
	model := commandPalette{
		commands: []string{
			"vault read secret/data/app",
			"vault status",
			"vault token lookup",
		},
	}
	h := steep.NewHarness(t, model, steep.WithInitialTermSize(48, 8))

	h.WaitContainsStrings(t, []string{"size=48x8", "vault read", "vault status"})
	h.Type("status")
	h.WaitContainsString(t, "query=status")
	h.AssertStringNotContains(t, "vault read secret/data/app")

	h.Send(tea.KeyPressMsg(tea.Key{Code: tea.KeyEnter}))
	selected := steep.WaitMessage[openCommandMsg](t, h)
	h.WaitContainsString(t, "opened=vault status")

	if selected.Command != "vault status" {
		t.Fatalf("selected command = %q, want vault status", selected.Command)
	}
}
```

## Component harness

Use `NewComponentHarness` for non-root components that expose `View() string`
and one of these update shapes:

```go
Update(tea.Msg) tea.Cmd
Update(tea.Msg) (M, tea.Cmd)
```

This is the main reason to prefer `steep` over older `teatest` guidance:
component-heavy TUIs can test reusable child models directly instead of wrapping
everything in a synthetic root model.

```go
package ui

import (
	"fmt"
	"strings"
	"testing"
	"time"

	tea "charm.land/bubbletea/v2"
	"github.com/lrstanley/x/charm/steep"
	"github.com/lrstanley/x/charm/steep/snapshot"
)

type inventoryRow struct {
	ID   string
	Name string
	Type string
}

type inventoryTable struct {
	width, height int
	rows          []inventoryRow
	filter        string
	selected      int
}

// [...]

func TestInventoryTable(t *testing.T) {
	table := &inventoryTable{}
	h := steep.NewComponentHarness(t, table, steep.WithInitialTermSize(32, 6))

	steep.Mutate(t, h, func(m *inventoryTable) *inventoryTable {
		m.rows = []inventoryRow{
			{ID: "secret-app", Name: "secret/app", Type: "kv"},
			{ID: "database", Name: "database", Type: "database"},
			{ID: "token", Name: "token", Type: "auth"},
		}
		return m
	})
	h.WaitContainsStrings(t, []string{"secret/app", "database", "token"})

	h.Type("j")
	h.WaitSettleMessages(
		t,
		steep.WithSettleTimeout(25*time.Millisecond),
		steep.WithCheckInterval(5*time.Millisecond),
	)

	steep.Mutate(t, h, func(m *inventoryTable) *inventoryTable {
		m.filter = "secret"
		m.selected = 0
		return m
	})
	h.WaitSettleView(t).
		AssertStringContains(t, "secret/app").
		AssertStringNotContains(t, "database", "token").
		RequireSnapshotNoANSI(t, snapshot.WithSuffix("inventory"))
}
```

## Common helpers

- `Type("text")` sends one key press per rune.
- `Send(msg)` sends any `tea.Msg` to the running program.
- `WaitContainsString`, `WaitContainsStrings`, and `WaitNotContainsString` wait
  for visible output.
- `WaitSettleMessages` waits until `Update` stops receiving messages for the
  configured settle timeout.
- `WaitSettleView` waits until repeated `View` samples stop changing.
- `Messages`, `MessagesOfType[T]`, `WaitMessage[T]`, `WaitMessages[T]`, and
  `WaitMessageWhere[T]` inspect observed messages.
- `Dimensions`, `AssertWidth`, `RequireWidth`, `AssertHeight`, `RequireHeight`,
  `AssertDimensions`, and `RequireDimensions` use ANSI-aware display width.
- `Assert*` helpers report errors and keep the test running. Use `Require*`
  helpers when the next step depends on the check passing and should stop
  immediately.

Most helpers exist in both package-level and harness-level forms. Use the
package-level helpers when you already have a simple value that implements
`View() string` and do not need runtime behavior:

```go
steep.AssertStringContains(t, model, "ready")
steep.AssertDimensions(t, model, 80, 24)
```

Harness methods are better when the test depends on window-size messages,
commands, key input, observed messages, snapshots, or final model state:

```go
h := steep.NewComponentHarness(t, model)
h.Type("j")
h.WaitContainsString(t, "selected")
```

Harness assertion and snapshot methods return `*Harness`, so they can be
chained after settle-style waits:

```go
h.WaitSettleView(t).
	AssertStringContains(t, "ready").
	AssertStringNotContains(t, "loading").
	RequireSnapshotNoANSI(t)
```

Content waits return the matched view output, which is useful when the test
needs to inspect the rendered string directly:

```go
out := h.WaitContainsString(t, "ready")
if strings.Contains(out, "warning") {
	t.Fatal("unexpected warning")
}
```

## Mutating models

Prefer to drive models through public behavior: send messages, type keys, or use
commands that a user could actually trigger. Use `Mutate` when the setup would
otherwise make a test noisy or impractical, such as seeding large component data
sets, setting an internal filter, or moving a component into a state that has no
public message.

`Mutate` runs from inside the Bubble Tea `Update` loop, keeping the harness state
consistent:

```go
steep.Mutate(t, h, func(m *inventoryTable) *inventoryTable {
	m.rows = rows
	m.filter = "secret"
	return m
})
```

Use it sparingly. If behavior can be tested by sending `tea.Msg` values or typing
keys, prefer that path because it covers the same route a real user takes.

## Snapshots

`steep` includes `github.com/lrstanley/x/charm/steep/snapshot` as an alternative
to `x/exp/golden` and `go-snaps`. Snapshots are written under `testdata`. Set
`UPDATE_SNAPSHOTS=true` or pass `snapshot.WithUpdate(true)` to create or update
snapshots.

```go
package ui

import (
	"bytes"
	"testing"

	"github.com/lrstanley/x/charm/steep/snapshot"
)

func TestStatusView(t *testing.T) {
	view := "\x1b[32mcluster=acme-corp\x1b[0m\nstatus=unsealed\ntoken=s.dev-token\n"

	snapshot.AssertEqual(
		t,
		view, // Or yourModel.View()
		snapshot.WithSuffix("status"),
		snapshot.WithStripANSI(),
		snapshot.WithTransform(func(bts []byte) []byte {
			return bytes.ReplaceAll(bts, []byte("s.dev-token"), []byte("<token>"))
		}),
	)
}
```

Use `snapshot.RequireEqual` when a mismatch should stop the test immediately.
For harnesses, use convenience methods:

```go
h.AssertSnapshot(t, snapshot.WithSuffix("ansi"))
h.AssertSnapshotNoANSI(t, snapshot.WithSuffix("plain"))
h.RequireSnapshot(t, snapshot.WithSuffix("ansi"))
h.RequireSnapshotNoANSI(t, snapshot.WithSuffix("plain"))
```

Use `WithSuffix` when a test writes more than one snapshot or when a subtest
needs a descriptive file name. Use `WithStripANSI` and `WithStripPrivate` when
terminal styling, spinners, or private-use glyphs would otherwise make snapshots
unstable.

## Taskfile integration

```yaml
# yaml-language-server: $schema=https://taskfile.dev/schema.json
version: "3"

tasks:
  test:
    desc: run tests
    cmds:
      - go test -count 5 -p 3 ./...
  test:update:
    desc: run tests and update snapshots
    cmds:
      - UPDATE_SNAPSHOTS=true go test -count 5 -p 3 ./...
```

## Do's

- Prefer `steep` harness tests for root models and component models.
- Prefer `steep` snapshots for view regression testing.
- Set size explicitly with `WithInitialTermSize` when layout matters.
- Use `WaitSettleView` or `WaitSettleMessages` before snapshotting animated,
  command-driven, or asynchronously updated views.
- Strip or transform unstable output such as spinner frames, timestamps, tokens,
  private-use glyphs, or machine-specific paths before comparing snapshots.

## Don'ts

- Keep using `teatest`, `x/exp/golden`, or `go-snaps` for new tests when `steep`
  covers the same behavior.
- Mutate state when typing keys or sending messages would test the real user
  path clearly.
- Snapshot before waiting for a stable view.
- Update snapshots in CI unless that step is explicitly requested.
