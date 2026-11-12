# Authoring Taskfiles

Patterns for writing and editing a `Taskfile.yaml`. Match the existing file's style (quoting,
`desc` casing, blank lines between tasks) when editing; use this skeleton for new files.

## Skeleton

Section order follows the official style guide: `version`, `includes`, root options, `vars`,
`env`/`dotenv`, `tasks`.

```yaml
# yaml-language-server: $schema=https://taskfile.dev/schema.json
version: "3"

method: timestamp
set: [errexit, nounset, pipefail]

dotenv: [.env.local, .env]

vars:
  PROJECT: myapp
  PACKAGE: github.com/example/myapp

env:
  CGO_ENABLED: 0

tasks:
  default:
    desc: build the project
    cmds:
      - task: build

  prepare:
    desc: run code generation
    aliases: [generate]
    run: once
    preconditions:
      - sh: test -f go.mod
        msg: "no go.mod found, run from the module root"
    sources:
      - "**/*.go"
      - exclude: "**/*.gen.go"
    generates:
      - "**/*.gen.go"
    cmds:
      - go generate -x ./...

  build:
    desc: build the binary
    deps: [prepare]
    sources:
      - "**/*.go"
      - go.mod
      - go.sum
      - exclude: "**/*_test.go"
    generates:
      - "{{.PROJECT}}{{exeExt}}"
    cmds:
      - go build -trimpath -o {{.PROJECT}}{{exeExt}} {{.PACKAGE}}

  test:
    desc: run tests
    deps: [prepare]
    cmds:
      - go test -timeout 5m {{default "./..." .CLI_ARGS}}

  test:extended:
    desc: run tests with the race detector, several times over
    deps: [prepare]
    env:
      GORACE: exitcode=1 halt_on_error=1
    cmds:
      - go test -race -count 3 -cpu 1,4 {{default "./..." .CLI_ARGS}}

  fmt:
    desc: format code
    aliases: [format]
    cmds:
      - golangci-lint fmt

  lint:
    desc: run linters, applying fixes
    cmds:
      - golangci-lint run --fix

  clean:
    desc: remove build artifacts
    cmds:
      - rm -rfv {{.PROJECT}}{{exeExt}}
```

And in `.gitignore`:

```gitignore
.task/
.env
.env.local
```

## Incremental tasks

Reach for this by default. Any task that turns files into other files, or does work whose
completion can be checked, should skip itself when nothing changed.

| Task shape | Mechanism |
| --- | --- |
| Inputs -> outputs (build, codegen, docs build, bundling) | `sources` + `generates` |
| Inputs -> no tracked output (dependency install, image build) | `sources` + `status` |
| "Already done" is a shell check (directory exists, image present) | `status` only |
| Re-run every time (fmt, lint, tidy, up, run, dev, release, clean) | none |

### Why `method: timestamp`

`checksum` (the default) hashes every source file on every run. `timestamp` compares
modification times against the outputs, which stays fast on large trees and node_modules-adjacent
globs. Set it once at the root. Override per task with `method: checksum` only when mtimes are
unreliable for that task (sources regenerated with identical content on every checkout).

Both methods keep state in `.task/` (checksums, or a saved timestamp when a task has no
`generates`), so gitignore `.task/` as soon as any task declares `sources`. `TASK_TEMP_DIR`
moves it elsewhere; leave the default unless the repo already sets one.

### Sources and generates

```yaml
docs:build:
  desc: build the docs
  dir: docs
  deps: [docs:install]
  sources:
    - "src/**/*"
    - "public/**/*"
    - package.json
    - bun.lock
    - "*.config.*"
  generates:
    - "dist/**/*"
  cmds:
    - bun run build
```

- Globs are relative to the task's `dir`.
- Include everything that changes the result: lockfiles, config files, embedded assets.
- Put `exclude:` entries after the glob they narrow.
- `generates` only checks that outputs exist (and their mtime under `timestamp`); it never
  hashes them.
- Deps still run (and do their own checks) even when the task itself is up to date.

### Sources plus status

When the output is not a file you can list, combine `sources` with a `status` check. Every
configured check must pass for the task to be skipped.

```yaml
docs:install:
  desc: install the docs' dependencies
  dir: docs
  run: once
  sources: [package.json, bun.lock]
  status:
    - test -d node_modules
  cmds:
    - bun install
```

```yaml
image:
  desc: build the container image
  method: checksum
  sources: [Dockerfile, "src/**/*"]
  status:
    - docker image inspect myapp:{{.CHECKSUM}} >/dev/null 2>&1
  cmds:
    - docker build -t myapp:{{.CHECKSUM}} .
```

`{{.CHECKSUM}}` needs `method: checksum`; under `timestamp` use `{{.TIMESTAMP.Unix}}`.

### Status only

```yaml
docs:demos:
  desc: record the docs demos (--force to re-record)
  # written last, so its absence means the set isn't complete.
  status:
    - test -f docs/fixtures/demo-sizes.json
  cmds:
    - rm -f docs/fixtures/demo-sizes.json
    - ./scripts/record-demos.sh
    - ./scripts/write-sizes.sh > docs/fixtures/demo-sizes.json
```

Write the marker file last so a half-finished run is retried. Status checks run on every call,
so keep them fast and read-only.

### Variants of one task

A task's fingerprint is keyed by its label. When a variable changes the output, put it in the
`label` and the `generates` path, or the variants overwrite each other's state:

```yaml
build:
  label: "build-{{.GOOS}}-{{.GOARCH}}"
  sources: ["**/*.go", go.mod, go.sum]
  generates: ["dist/{{.PROJECT}}-{{.GOOS}}-{{.GOARCH}}{{exeExt}}"]
  cmds:
    - go build -o dist/{{.PROJECT}}-{{.GOOS}}-{{.GOARCH}}{{exeExt}} .
```

### When not to

- The task rewrites its own sources (`fmt`, `lint --fix`, `go mod tidy`, `up`): every run
  invalidates the fingerprint it just saved.
- The task exists for its effect (`run`, `dev`, `debug`, `release`, `deploy`, `clean`).
- Tests run with `-count` or flaky/external inputs. Skipping them hides regressions; if a test
  task is slow and deterministic, `sources` alone is acceptable.

`task --status <name>` reports whether a task is up to date; `task --force <name>` ignores
every check (preconditions included).

## Preconditions, status, and if

| Field | A failing check means |
| --- | --- |
| `preconditions` | stop with an error (and fail callers) |
| `status` | the work is not done yet, so run it |
| `if` | skip this task or command without failing |
| `requires` | a variable is missing or outside its `enum` |

```yaml
release:
  desc: release the module, printing the plan unless given --apply (task release -- <version> [--apply])
  preconditions:
    - sh: test -n {{shellQuote .CLI_ARGS}}
      msg: "usage: task release -- <major|minor|patch|version> [--alpha|--beta|--rc] [--apply]"
    - sh: test -n "${GH_TOKEN:-}"
      msg: "GH_TOKEN not set, try: GH_TOKEN=$(gh auth token) task release -- ..."
  cmds:
    - go run {{.MODRELEASE}} {{.CLI_ARGS}}

docs:dev:
  desc: run the docs' dev server
  dir: docs
  deps: [docs:install]
  preconditions:
    - sh: command -v bun
      msg: "bun not found, install from https://bun.sh"
  cmds:
    - bun run dev

deploy:
  desc: deploy to an environment
  requires:
    vars:
      - name: ENV
        enum: [staging, production]
  prompt: "deploy to {{.ENV}}?"
  cmds:
    - ./scripts/deploy.sh {{.ENV}}
```

- Every `msg` names the fix (install command, file to copy, env var to set), not only what is
  missing.
- A plain string works when the failure explains itself: `preconditions: [test -f go.mod]`.
- Deps run before the precondition is evaluated; put the check on the task that needs it.
- Use `prompt` on destructive tasks; `task --yes` accepts it in CI.

## Variables and arguments

```yaml
vars:
  MODULES: [".", _examples, docs/_tools]   # lists are real arrays
  VERSION:
    sh: git describe --tags --always 2>/dev/null || echo "0.0.0"
  PROFILE: '{{.PROFILE | default "debug"}}'  # keeps `task build PROFILE=release`
```

- Pass-through args: `{{.CLI_ARGS}}`, with a default for the common case:
  `go test {{default "./..." .CLI_ARGS}}`. Quote when the args form one shell word:
  `{{shellQuote .CLI_ARGS}}`.
- A constant in a task's own `vars:` overrides the command line. Put defaults in root `vars`
  or use `default`.
- `vars` are template-only; commands do not see them as env vars. Use `env:` to export, e.g.
  `env: {GOFLAGS: "-ldflags=-X=main.version={{.VERSION}}"}`.
- Uppercase variable names. `sh:` vars run on every invocation, so keep them cheap and give
  them a fallback (`|| echo ...`) so the Taskfile still loads outside a git checkout.

## Env files

```yaml
dotenv: [.env.local, .env]
```

- The first file that defines a name wins, so list local overrides first.
- Missing files are skipped silently; the process environment wins over both by default.
- Task-level `env:` beats dotenv values. Task-level `dotenv` can template on call vars
  (`.env.{{.ENV}}`); root-level cannot.
- Not supported in included Taskfiles: load it in the entrypoint.
- Gitignore the files; commit an `.env.example` and point a precondition `msg` at it.

## Multiple modules and loops

```yaml
vars:
  MODULES: [reel, ".", cmd/reel, _examples]   # in dependency order

tasks:
  tidy:
    desc: run go mod tidy in every module
    cmds:
      - for: { var: MODULES, as: MODULE }
        cmd: cd {{.MODULE}} && go mod tidy

  test:
    desc: run tests in every module
    cmds:
      - for: { var: MODULES, as: MODULE }
        cmd: cd {{.MODULE}} && go test {{default "./..." .CLI_ARGS}}
```

- `cd` inside one `cmd` is fine; it does not carry to the next entry.
- For a single subproject, use the task's `dir:` instead of `cd`.
- Offer `<action>:all` variants when the root task acts on the current module only and a
  fan-out version is also useful (`test` and `test:all`).

## Ordering and repeated calls

```yaml
default:
  desc: format and test all modules
  cmds:
    - task: fmt     # runs first, blocks
    - task: test

docs:build:
  deps: [docs:install, docs:demos]   # concurrent, any order
```

- `deps` run concurrently; use them only for independent prerequisites.
- `run: once` on prerequisites called from several tasks (`prepare`, `tidy`, `install`), so one
  invocation runs them once. This is per invocation; incremental checks are across invocations.
- `defer:` runs cleanup in reverse order whether the task fails or not:
  `- defer: docker compose down`.

## Includes

```yaml
includes:
  web:
    taskfile: web/Taskfile.yaml
    dir: web
  main:
    taskfile: ../../Taskfile.yaml
    flatten: true      # merge without the main: prefix
```

- Included tasks are namespaced (`web:build`), matching the colon naming convention.
- An included file's own `vars` apply after `includes.vars`; use `default` there to accept the
  parent's value.
- Keep each included Taskfile runnable on its own from its directory.

## Small tasks and multi-line commands

```yaml
profile:cpu: go tool pprof -http :6061 'http://127.0.0.1:6060/debug/pprof/profile?seconds=15'
```

A one-command task can be a bare string. Keep multi-line `|` blocks short; move anything with
real control flow into `.github/scripts/<name>.sh` (or the repo's scripts dir) and call it.

## Converting from Make

| Make | Task |
| --- | --- |
| `.PHONY: test` | every task is phony unless it has `sources`/`status` |
| `out: in1 in2` file targets | `sources: [in1, in2]` + `generates: [out]` |
| `VAR ?= val` | `VAR: '{{.VAR \| default "val"}}'` |
| `build: fmt lint` | `deps: [fmt, lint]` (concurrent) or `cmds: [{task: fmt}, {task: lint}]` (ordered) |
| `export FOO=bar` | `env: {FOO: bar}` |
| `include other.mk` | `includes: {other: ./other/Taskfile.yaml}` |

Make's file targets map directly onto `sources`/`generates`: keep them incremental when
converting rather than flattening them into always-run tasks.
