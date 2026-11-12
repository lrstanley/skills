# Running and Reading Taskfiles

How to use a project's existing Taskfile to build, test, and run things, and how to reproduce
a task when `task` is not installed.

## Finding the Taskfile

Task looks for `Taskfile.yml` / `Taskfile.yaml` (either case), then the `.dist.` variants.
A `.dist.` file is the committed baseline; a
gitignored `Taskfile.yaml` next to it is a local override. Then follow `includes` to find
namespaced sub-Taskfiles (`web:build` lives in `web/Taskfile.yaml`).

Task also searches parent directories, so `task test` works from a subdirectory; the task still
runs in the Taskfile's directory unless it sets `dir`.

## Mapping intent to a task

1. `task --list` (definition order: `task --list --sort none`). `task --list-all` adds tasks
   without a `desc`; `internal` tasks stay hidden from both, so read the file for those.
2. Match intent to the vocabulary in `SKILL.md`, then check `aliases` (`format` -> `fmt`,
   `generate` -> `prepare`, `dev` -> `debug`).
3. When two tasks fit (`test` vs `test:extended`, `run` vs `dev`), read their `desc` and pick
   the narrower one unless asked for the thorough run.
4. `task --summary <name>` prints a task's long description, deps, and commands.

## Reading a task before running it

| Field | What it changes |
| --- | --- |
| `deps` | tasks that run first, concurrently |
| `vars`, `env`, `dotenv` | tool selection, flags, credentials the raw command would miss |
| `dir` | where the commands run |
| `preconditions`, `requires` | what must exist or be passed first |
| `sources`, `generates`, `status` | when the task skips itself |
| `prompt`, `interactive` | whether it needs a terminal |
| `internal` | a helper: run the public task that calls it |

Run the task, not the command inside it: `task test`, not `go test ./...`. The task may carry
env (`GORACE`, `CGO_ENABLED`), a `prepare` dep that regenerates code, or a fan-out across
modules.

## CLI

```bash
task                          # default task
task <name>                   # run a task (and its deps)
task <name> -- -run TestFoo   # args after -- land in {{.CLI_ARGS}}
task <name> VAR=value         # set a variable
task -d path/to/dir <name>    # run from another directory's Taskfile
task --dry <name>             # print commands without running them
task --status <name>          # exit non-zero if not up to date
task --force <name>           # ignore up-to-date checks and preconditions
task -p lint test             # run several tasks in parallel
task --watch <name>           # re-run when sources change
task --yes <name>             # accept prompts (needed in CI)
```

### Outcomes to recognize

- `task: Task "build" is up to date`: incremental skip, not a failure. Use `--force` only when
  you need the commands to run regardless.
- A precondition failure prints its `msg`: fix what it says rather than bypassing with
  `--force`.
- Exit code `205`: a `prompt` was declined. Without a terminal, prompts fail unless `--yes`
  is passed; pass it only when the user asked for the action.
- Exit code `201`: a precondition failed (its `msg` is printed above).
- `task: Task "x" does not exist`: check `--list-all` for a namespace (`docs:x`) or alias.

## Running without `task`

Prefer installing it (`go install github.com/go-task/task/v3/cmd/task@latest`, `brew install
go-task`, or the repo's documented method). When that is not possible, reproduce the task in
full:

1. Load `dotenv` files (first file wins; the process environment wins over both).
2. Resolve root then task `vars`, including `sh:` vars, and the `CLI_ARGS` default.
3. Run every `deps` entry the same way, recursively.
4. Check `preconditions`; stop if one fails.
5. Export `env`, apply `set` options (`set -euo pipefail`), and `cd` to `dir`.
6. Run each `cmds` entry in a fresh shell, in order, expanding `for` loops and `task:` calls.

Reducing `task test` to the bare tool command skips deps, env, and module fan-out, so the
result will not match what the task would do.
