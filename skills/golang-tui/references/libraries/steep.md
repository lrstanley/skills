# Testing Bubble Tea Applications with steep

Use `github.com/lrstanley/x/term/steep` for Bubble Tea integration tests,
component tests, view assertions, and snapshots. `steep` is the preferred
alternative to `github.com/charmbracelet/x/exp/teatest/v2`,
`github.com/charmbracelet/x/exp/golden`, and `github.com/gkampitakis/go-snaps`
for TUI testing in this skill.

`steep` runs models through the real Bubble Tea runtime inside an emulated
terminal (a `reel` session), sends keys, text, mouse events, and resizes,
waits for output, observes messages, mutates state inside `Update`, and writes
snapshots under `testdata`. The harness is bound to the `testing.TB` passed to
`NewHarness`, so methods do not take `t`, and most return `*Harness` for chaining.

Requires Go 1.27+ (generic harness methods such as `Mutate`, `WaitMessage[T]`).
It was previously `github.com/lrstanley/x/charm/steep`; update old import paths.

Upstream reference: [steep README](https://github.com/lrstanley/x/tree/master/term/steep).

## When to use

- Testing a full Bubble Tea root model that implements `tea.Model`.
- Testing a component model that has `View() string` plus an `Update` method.
- Waiting for rendered output after key presses, messages, commands, or async
  work.
- Asserting view content, ANSI-aware dimensions, observed messages, or snapshots.
- Recording a failing test as a GIF or asciicast for debugging or docs.
- Replacing older `teatest`, `golden`, or `go-snaps` guidance in TUI tests.

## When not to use

- Pure functions that can be tested directly without a Bubble Tea runtime.
- Slow end-to-end tests that need a real shell session.
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
	"github.com/lrstanley/x/term/steep"
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
	h := steep.NewHarness(t, model, steep.WithWindowSize(48, 8))

	h.Wait([]string{"size=48x8", "vault read", "vault status"})
	h.Type("status").
		Wait("query=status").
		AssertNot("vault read secret/data/app")

	h.Key("enter")
	selected := h.WaitMessage[openCommandMsg]()
	h.Wait("opened=vault status")

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

	tea "charm.land/bubbletea/v2"
	"github.com/lrstanley/x/term/steep"
	"github.com/lrstanley/x/term/steep/snapshot"
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
	h := steep.NewComponentHarness(t, table, steep.WithWindowSize(32, 6))

	h.Mutate(func(m *inventoryTable) *inventoryTable {
		m.rows = []inventoryRow{
			{ID: "secret-app", Name: "secret/app", Type: "kv"},
			{ID: "database", Name: "database", Type: "database"},
			{ID: "token", Name: "token", Type: "auth"},
		}
		return m
	})
	h.Wait([]string{"secret/app", "database", "token"})

	h.Type("j").WaitSettleMessages()

	h.Mutate(func(m *inventoryTable) *inventoryTable {
		m.filter = "secret"
		m.selected = 0
		return m
	})
	h.WaitSettle().
		Assert("secret/app").
		AssertNot([]string{"database", "token"}).
		RequireSnapshot(snapshot.WithSuffix("inventory"))
}
```

## Common helpers

- `Type("text")` sends one key press per rune. `Key("ctrl+c")`, `KeyUp`,
  `KeyEsc`, `Paste`, `LeftClick`, `MouseDrag`, `Resize`, `Focus`, and `Blur`
  drive the terminal. `SendProgram(msg)` sends any event to the program.
- `Wait`, `WaitNot`, and `WaitFor(cond)` wait for visible output (string,
  `[]string`, or `[]byte`).
- `WaitSettle` waits until the screen stops changing. `WaitSettleMessages`
  waits until `Update` stops receiving messages (see `WithSettle`,
  `WithSettleIgnoreMsgs` for periodic ticks).
- `MessageHistory`, `FilterMessagesType[T]`, `WaitMessage[T]`,
  `WaitMessageWhere[T]`, and `AssertHasMessage[T]` inspect observed messages.
- `AssertWidth`, `AssertHeight`, `AssertDimensions` (and `Require*`) use
  ANSI-aware display width.
- `Assert*` helpers report errors and keep the test running. Use `Require*`
  helpers when the next step depends on the check passing and should stop
  immediately.
- `QuitProgram`, `WaitFinished`, and `FinalModelAs[M]` inspect the final state.
- Tune with options: `WithTimeout`, `WithCheck`, `WithSettle`, `WithANSI`,
  `WithEnvVars`, `WithLog`. Most can also be set via `STEEP_*` env vars unless
  `WithIgnoreEnv(true)`.

Package-level `steep.Assert`, `steep.AssertNot`, `steep.AssertDimensions`, and
friends take `(t, view, ...)` for a simple value with `View() string` and no
runtime behavior:

```go
steep.Assert(t, model, "ready")
steep.AssertDimensions(t, model, 80, 24)
```

Harness methods are better when the test depends on window-size messages,
commands, key input, observed messages, snapshots, or final model state.
Waits and assertions return `*Harness`, so they chain:

```go
h.WaitSettle().
	Assert("ready").
	AssertNot("loading").
	RequireSnapshot()
```

## Mutating models

Prefer to drive models through public behavior: send messages, type keys, or use
commands that a user could actually trigger. Use `Mutate` when the setup would
otherwise make a test noisy or impractical, such as seeding large component data
sets, setting an internal filter, or moving a component into a state that has no
public message.

`Mutate` runs from inside the Bubble Tea `Update` loop, keeping the harness state
consistent. `fn` must take and return the model type passed to the harness:

```go
h.Mutate(func(m *inventoryTable) *inventoryTable {
	m.rows = rows
	m.filter = "secret"
	return m
})
```

Use it sparingly. If behavior can be tested by sending messages or typing
keys, prefer that path because it covers the same route a real user takes.

## Snapshots

`steep` includes `github.com/lrstanley/x/term/steep/snapshot` as an alternative
to `x/exp/golden` and `go-snaps`. Snapshots are written under `testdata`. Set
`UPDATE_SNAPSHOTS=true` or pass `snapshot.WithUpdate(true)` to create or update
snapshots. `STEEP_SNAPSHOT_DIR` sets the default directory (`snapshot.WithDir`
still wins).

```go
package ui

import (
	"bytes"
	"testing"

	"github.com/lrstanley/x/term/steep/snapshot"
)

func TestStatusView(t *testing.T) {
	view := "\x1b[32mcluster=acme-corp\x1b[0m\nstatus=unsealed\ntoken=s.dev-token\n"

	snapshot.AssertEqual(
		t,
		view, // Or yourModel.View()
		snapshot.WithSuffix("status"),
		snapshot.WithANSI(false),
		snapshot.WithTransform(func(bts []byte) []byte {
			return bytes.ReplaceAll(bts, []byte("s.dev-token"), []byte("<token>"))
		}),
	)
}
```

Use `snapshot.RequireEqual` when a mismatch should stop the test immediately.
For harnesses, use convenience methods (they follow the harness `WithANSI`
setting, ANSI is kept by default):

```go
h.AssertSnapshot(snapshot.WithSuffix("ansi"))
h.RequireSnapshot(snapshot.WithSuffix("plain"), snapshot.WithANSI(false))
h.AssertJSON()
```

Use `WithSuffix` when a test writes more than one snapshot or when a subtest
needs a descriptive file name. Use `WithANSI(false)`, `WithPrivate(false)`, and
`WithSpinners(false)` when terminal styling, private-use glyphs, or spinners
would otherwise make snapshots unstable.

## Recording failures

Nothing is written by default. `WithExportOnFailure()` (or `WithExportAlways()`)
writes a recording once, at harness close, to `t.ArtifactDir()` (kept with
`go test -artifacts`) or `WithArtifacts(dir)`. `WithRecording` takes a
`reel.Profile` for outputs and effects:

```go
h := steep.NewHarness(t, newModel(),
	steep.WithRecording(reel.Profile{
		Outputs: reel.MustFiles("{name}_{status}.gif", "{name}_{status}.cast"),
		Effects: []reel.Effect{
			steep.Logo(2 * time.Second),
			effects.Keys(time.Second),
			effects.Pause(),
			steep.Outro(2 * time.Second),
		},
	}),
	steep.WithExportOnFailure(),
)
```

Any existing test can be recorded without code changes:

```sh
STEEP_EXPORT_MODE=on STEEP_EXPORT='{name}.gif?max-bytes=5MB,{name}.cast' go test -artifacts ./...
```

Other variables: `STEEP_EXPORT_DIR`, `STEEP_EXPORT_FPS`, `STEEP_EXPORT_SPEED`,
`STEEP_TYPING_DELAY` (pause after each key, for readable recordings),
`STEEP_RECORD_MESSAGES`. The `.cast` file also holds annotations (inputs,
waits, assertions, failures, terminal queries) that players ignore.

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
- Set size explicitly with `WithWindowSize` when layout matters.
- Use `WaitSettle` or `WaitSettleMessages` before snapshotting animated,
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
