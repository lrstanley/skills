---
name: taskfile
description: >-
  Writes, edits, and runs go-task Taskfiles (Taskfile.yaml) using a consistent task vocabulary,
  incremental builds, and preconditions. Use when creating or changing a Taskfile, adding or
  renaming tasks, converting a Makefile or scripts to Task, or running a project's build, test,
  lint, fmt, or dev commands in a repo that has a Taskfile.
license: MIT
metadata:
  author: https://github.com/lrstanley
  domain: devops
  triggers: Taskfile, Taskfile.yaml, Taskfile.yml, go-task, task runner, task --list, sources, generates, method timestamp, preconditions, dotenv, CLI_ARGS, Makefile conversion
  role: specialist
  scope: implementation
  output-format: code
  related-skills: golang
---

# Taskfile

Specialist in [Task](https://taskfile.dev) (go-task). A Taskfile is the repo's command
vocabulary: `task test` means the same thing in a Go module, a bun docs site, or a monorepo,
and wraps the env, deps, and flags the raw tool command would miss.

## Workflow

1. **Find the Taskfile.** `Taskfile.yaml`, `Taskfile.yml`, or a `.dist.` variant at the repo
   root, plus anything under `includes`. Edit the existing file; create `Taskfile.yaml` only
   when none exists.
2. **Read before running.** Run `task --list`, then read the task's `deps`, `vars`, `env`,
   `dotenv`, `dir`, and `preconditions`. Run `task <name>`, not the tool command it wraps.
3. **Name from the vocabulary** below, matching what the file already uses.
4. **Make it incremental** wherever a task turns inputs into outputs, and guard it with
   `preconditions`.
5. **Verify.** `task --list` parses the file; run the changed task twice and confirm the
   second run reports "up to date" for incremental tasks.

## Vocabulary

| Name | Purpose |
| --- | --- |
| `default` | the most common workflow, via `cmds: [{task: build}]` or similar |
| `fmt` (alias `format`) | format code |
| `lint` | lint, applying safe fixes |
| `test` | fast test run; `test:extended` for race/count/multi-CPU runs |
| `prepare` (alias `generate`) | code generation and other build prerequisites |
| `build`, `run` / `dev` / `debug` | build the artifact; run it locally |
| `tidy` / `fetch`, `up` | resolve dependencies; upgrade them |
| `license`, `clean`, `release`, `setup` | headers, remove artifacts, cut a release, bootstrap workspace |
| `<component>:<action>` | `docs:install`, `docs:dev`, `docs:build`, `vault:up` |
| `<action>:<variant>` | `test:extended`, `test:update`, `fmt:all` (fan-out across modules) |

## Constraints

### MUST DO

- Start every Taskfile with `# yaml-language-server: $schema=https://taskfile.dev/schema.json`,
  then `version: "3"`.
- Keep top-level tasks unprefixed (`build`, `test`). When a task belongs to a component or is
  a variant, namespace it with colons: `docs:build`, `test:extended`.
- Make every task incremental that can be: `sources` + `generates` for build, codegen,
  install, and docs builds; `status` when "already done" is a shell check.
- Set `method: timestamp` at the root when using `sources`.
- Add `.task/` to `.gitignore` whenever any task uses `sources`. Task stores fingerprints there.
- Guard external requirements with `preconditions` carrying a `msg` that says how to fix it
  (`command -v bun`, `test -f go.mod`, `test -n {{shellQuote .CLI_ARGS}}` with a usage line).
- Load env files with root `dotenv` (`[.env.local, .env]`: first file wins) and gitignore them.
- Give every user-facing task a `desc`; mark helpers `internal: true`.
- Set `set: [errexit, nounset, pipefail]` at the root; mark shared deps (`prepare`, `tidy`)
  `run: once`.
- Use `dir:` for subproject tasks, and `cmds` with `- task: x` when order matters.
- Check unfamiliar keys and template functions against the docs index before using them.

### MUST NOT DO

- Name tasks with dashes or underscores for namespacing (`docs-build`, `test_extended`).
- Call the wrapped tool directly (`go test`, `bun run build`) when a task covers it.
- Mark incremental a task that rewrites its own sources (`fmt`, `lint --fix`, `tidy`, `up`)
  or exists for its side effect (`run`, `dev`, `release`, `clean`).
- Rely on `cd` or `export` carrying between `cmds` entries; each runs in its own shell.
- Put order-dependent tasks in `deps`; deps run concurrently.
- Use `status` to block a task (that is `preconditions`), or `preconditions` to skip one.
- Put `dotenv` in an included Taskfile (unsupported), or embed secrets in the Taskfile.

## References

| Topic | Reference | Load when |
| --- | --- | --- |
| Authoring | `references/authoring.md` | Creating or editing a Taskfile: incremental, preconditions, vars, dotenv, loops, includes, gotchas |
| Running | `references/running.md` | Running tasks, passing args, reading an unfamiliar Taskfile, running without `task` installed |

Task's docs are indexed at <https://taskfile.dev/llms.txt>; append `.md` to any docs URL for
raw Markdown. The schema (`/docs/reference/schema.md`) and templating reference
(`/docs/reference/templating.md`) are the sources of truth for keys and functions.
