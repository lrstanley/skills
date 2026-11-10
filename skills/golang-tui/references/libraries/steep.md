# Testing and Driving Terminal Programs with steep and reel

[steep](https://github.com/lrstanley/steep) (`github.com/lrstanley/steep`) is the default
for testing terminal programs in this skill. The same repository ships three tools that
share one terminal emulator, one recording format (asciicast `.cast`), and the same output
formats and effects:

| Tool | Import / install | Use for |
| --- | --- | --- |
| steep | `go get github.com/lrstanley/steep@latest` | Go tests of Bubble Tea models, components, or any command on a pseudo-terminal |
| reel | `go get github.com/lrstanley/steep/reel@latest` | Recording or rendering a terminal from Go outside a test (demos, tooling, custom effects) |
| reel CLI | `go install github.com/lrstanley/steep/cmd/reel@latest` | Anything without Go: VHS tapes, tape-based tests, recording, rendering `.cast` files, and `reel session` for agents |

All three are pre-1.0. This file stays high level on purpose. **Read the docs for the
current API before writing code**; do not rely on memory for option or method names.

## Documentation (read these, not this file, for details)

The docs are published as markdown for agents. Start from the section index that matches
the task, then open only the pages you need:

- Overview, which tool to use: <https://getsteep.dev/llms.txt>
- steep (Go test harness): <https://getsteep.dev/steep/llms.txt>
- reel (Go library): <https://getsteep.dev/reel/llms.txt>
- reel CLI: <https://getsteep.dev/cli/llms.txt>
- Agent sessions: <https://getsteep.dev/cli/sessions.md>
- Everything in one file (large): <https://getsteep.dev/llms-full.txt>
- API reference: <https://pkg.go.dev/github.com/lrstanley/steep>
- Runnable examples: <https://github.com/lrstanley/steep/tree/master/_examples>

Every docs page is also available as markdown at its path plus `.md`.

The docs track the default branch, which can be ahead of the latest tag. If a documented
name or signature does not compile, check the version pinned in `go.mod` with
`go doc github.com/lrstanley/steep <Symbol>` (or pkg.go.dev for that version), or upgrade.

## steep: what it covers

steep runs a program in an emulated terminal, drives it like a user would, and asserts on
what it draws. At a high level it provides:

- **Three harnesses**: a root `tea.Model`, a single component (anything with
  `View() string` plus an `Update` method), or any command on a pseudo-terminal (exec
  harness, which also covers `main`, flags, and exit status, and works for non-Go or
  non-Bubble Tea programs).
- **Input**: keys, typed text, paste, mouse clicks/drags/wheel, focus/blur, resizes.
- **Waits and checks**: wait for text or conditions, wait for the screen or the message
  stream to settle, assert or require (stop on failure), and locate text on screen.
- **Program access** (model and component harnesses): send messages, observe and wait
  for messages, mutate the model inside `Update`, and inspect the final model.
- **Terminal state**: title, cursor, clipboard, colors, and what the program asked the
  terminal for.
- **Snapshots**: text (with or without ANSI) and JSON golden files under `testdata`,
  updated with `UPDATE_SNAPSHOTS=true`.
- **Recordings**: export GIF/video/`.cast`/stills on failure (or always), with effects
  such as key overlays, configurable from code or `STEEP_*` environment variables, and
  viewable in the [inspector](https://inspector.getsteep.dev/).

Pick the harness with <https://getsteep.dev/steep/harnesses.md>. For an existing app with
no tests, follow <https://getsteep.dev/steep/existing-project.md> (start with an exec
smoke test, then move to model and component tests where they pay off).

## Shape of a test

Illustrative only; check the docs for current names and options.

```go
package ui

import (
	"testing"

	"github.com/lrstanley/steep"
)

func TestNotes(t *testing.T) {
	h := steep.NewHarness(t, newModel(), steep.WithWindowSize(80, 12))
	h.Wait("Groceries")
	h.LeftClick(3, 2).Wait("A terminal garden")
	h.Key("d").Wait(`Delete "Ideas"?`)
	h.AssertSnapshot()
	h.Key("ctrl+c")
	h.WaitFinished()
}
```

The harness is bound to the `testing.TB` it was created with, and most methods chain.

## reel session: agents driving any TUI

`reel session` (`reel s`) runs a program in a detached, recorded terminal and drives it
one command at a time, reading the screen back as text, JSON, or an image. It needs no
code, so use it whenever an agent has to operate or verify a terminal program that does
**not** have steep tests: third-party libraries and apps we are fixing, debugging, or
adding features to, reproducing a reported bug, or checking a change end to end by hand.

```console
reel s start --name app --size 100x30 -- go run ./cmd/app
reel s wait --text "Ready"
reel s key down down enter
reel s type "query"
reel s wait --idle 500ms --print
reel s screen            # cheap text view of the current screen
reel s still -o shot.png # look at it as an image when layout or color matters
reel s stop -o repro.gif -o repro.cast
```

Guidance for agents (details and flags in <https://getsteep.dev/cli/sessions.md> and
<https://getsteep.dev/cli/commands/session.md>):

- Never `sleep` between commands; use `reel s wait` (text, regexp, gone, idle).
- Prefer `reel s screen` (text) for checks; use JSON for colors/cursor, and stills only
  when visual inspection is needed. Save stills under a temp directory, not the repo.
- Use `--json` and the stable exit codes for scripted flows, and `reel s do` with a tape
  to batch several steps in one call.
- Stop sessions you start. Stopping with outputs keeps the recording as evidence.
- If the code under test is ours and in Go, turn the reproduction into a steep test.

## reel CLI and reel library

- **Demos and docs GIFs**: `reel run` executes VHS tapes as-is (no browser or `ttyd`).
  Prefer it over `vhs` for new tapes.
- **Black-box tests without Go**: `reel test` runs tapes as tests with waits and golden
  files.
- **Existing recordings**: `reel export`, `still`, `cut`, `convert`, `info`, and `play`
  render, trim, and describe `.cast` files from reel, steep, or asciinema.
- **From Go outside tests**: the `reel` library opens sessions, runs commands, and exports
  timelines. Inside `go test`, use steep instead, which adds waits, assertions, and failure
  handling on top of reel.

## When not to use

- Pure functions or layout math: test directly. For bloom layouts, `bloom.Render` and
  `bloom.Solve` cover most cases without a runtime (see `references/libraries/bloom.md`).
- Do not add `teatest` (`x/exp/teatest`), `x/exp/golden`, or `go-snaps` to new tests;
  migrate them to steep when touching those tests.

## Do's

- Set the terminal size explicitly when layout matters.
- Wait for a stable screen (settle) before snapshotting animated or async views.
- Drive behavior through user input and messages; mutate the model only when setup
  would otherwise be impractical.
- Make output deterministic: strip or transform spinners, timestamps, tokens, and
  machine-specific paths; give bloom animations a controllable clock.
- Keep failure recordings in CI as artifacts (see <https://getsteep.dev/steep/ci.md>).

## Don'ts

- Use `time.Sleep` in tests or between `reel session` commands.
- Snapshot before the view settles.
- Update snapshots in CI unless explicitly requested.
- Write recordings or stills into the working tree unless they are deliverables.
