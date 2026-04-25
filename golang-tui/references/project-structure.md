# TUI Project Structure

## Recommended Layout

```
project/
  LICENSE
  README.md
  Taskfile.yaml or Makefile
  go.mod
  internal/
    [...]/
      [...].go
    config/               # user configuration loading/saving
      [...].go
    types/                # shared types to avoid cyclic dependencies between UI sub-packages
      component.go        # e.g. if you have a generic component interface
      keymap.go           # centralized key bindings
      [...].go            # message types, state types, helpers
    ui/                   # keep all models, components, etc under this directory
      components/         # reusable UI components
        statusbar/
          [...].go
        [...]/
          [...].go
      dialogs/            # modal dialog components
        confirm/
          [...].go
        [...]/
          [...].go
      pages/              # full-screen page components (drill-down stacks)
        [...]/
          [...].go
      state/              # state managers (page, dialog, navigation)
        [...].go
      styles/             # theme, colors, icon constants
        theme.go
        constants.go
        [...].go
      tui.go              # root model (implements tea.Model)
  main.go
```

## Multiple CLIs

If you opt for multiple different CLIs, rather than a single CLI with subcommands,
use the Go-standard `cmd/<name>/` directory pattern for the entrypoint.

## Keep main.go Minimal

main.go should only handle flag parsing, dependency creation, and running the program.
All UI logic lives under `internal/ui/`.

```go
package main

import (
    "errors"
    "fmt"
    "log/slog"
    "os"

    tea "charm.land/bubbletea/v2"
    "myapp/internal/config"
    "myapp/internal/ui"
)

func main() {
    // Initialize flags, config, etc here.

    p := tea.NewProgram(ui.New(client, cfg))

    if _, err := p.Run(); err != nil {
        if errors.Is(err, tea.ErrProgramPanic) {
            panic(err)
        }
        fmt.Fprintf(os.Stderr, "failed to run program: %v\n", err)
        os.Exit(1)
    }
}
```

## internal/types/

Shared types used across `ui/`, `config/`, etc. Placing these here avoids
cyclic import dependencies between UI sub-packages.

Common contents:

- **component.go** -- Component interface and base struct, if used (see `references/child-model-composition.md`)
- **keymap.go** -- Centralized key bindings (see `references/keymaps.md`)
- **Message types** -- Custom messages and other `Msg` and `Cmd` helpers/types
- **State types** -- Focus IDs, navigation state, entity types

## internal/ui/tui.go

The root model lives here. It implements `tea.Model` and orchestrates top-level concerns:

- Handling `tea.WindowSizeMsg`, `tea.ColorProfileMsg`, `tea.BackgroundColorMsg`, etc
- Theme initialization and updates
- Routing between pages, dialogs, status bars, etc
- Global key handling (quit, help, theme cycling, etc)

## internal/ui/styles/

Centralizes all visual configuration:

- **theme.go** -- Centralizes all visual configuration (colors, tints, styles, etc)
- **constants.go** -- Icon/glyph constants with fallbacks (see `references/libraries/go-nf.md`)
- Package-level lipgloss styles used across components (see `references/view-styling.md` and `references/libraries/lipgloss-v2.md`)

## Taskfile.yaml

```yaml
# yaml-language-server: $schema=https://taskfile.dev/schema.json
version: "3"
vars:
  PROJECT: "myapp"
  PACKAGE: "github.com/myorg/myapp"

tasks:
  build:
    desc: build the application
    cmds:
      - go build
  debug:
    desc: run in debug mode
    interactive: true
    cmds:
      - go run
  debug:basic:
    desc: run with reduced color depth for testing
    interactive: true
    cmds:
      - TERM="xterm-color" COLORTERM="xterm-color" go run
  test:
    desc: run tests
    cmds:
      - go test -count 5 -p 3
  test:update:
    desc: run tests and update snapshots
    cmds:
      - UPDATE_SNAPS=always go test -count 2 -p 3
  lint:
    desc: run linter
    cmds:
      - golangci-lint run --fix
  fmt:
    desc: format code
    cmds:
      - gofumpt -w .
```

The `debug:basic` task forces reduced color output by setting `TERM` and `COLORTERM`.
This verifies that your ANSI fallback colors work correctly. See `references/terminal-standards.md`
for more details.
