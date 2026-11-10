# Tests tier

An on-demand pass that finds low-value tests across a repository: tests that do not
validate anything meaningful, duplicate other tests, or would not fail if the behavior
broke. It replaces steps 1-5 of the main workflow for that run. The reviewer rules
(read-only, one brief per reviewer, no subagents), the reviewer models, the ledger, and
the report format still apply.

## When

Run it only when the user asks to clean up, purge, prune, audit, or refactor tests, or
passes `tests` as the `/review` argument. Never pick it during triage of a normal change.

Run it alone. Do not combine it with the correctness, structure, cleanup, or performance
lenses in the same run. If the user asks for both, finish one run, then start the other.

## 1. Scope and shards

The scope is the whole repository unless the user named paths or packages. It covers
test code, not a diff.

1. List the test files with `git ls-files`, matching the project's conventions (for
   example `*_test.go`, `test_*.py`, `*_test.py`, `*.test.*`, `*.spec.*`, `tests/`,
   `__tests__/`, `testdata/` drivers). Skip vendored, generated, and fixture-only files.
2. Run the test suite once and record the result. Note tests that already fail, skip, or
   are flaky. If the suite cannot run, say so; findings then rely on reading only.
3. Split the files into at most **3 shards**, grouped by package or top-level directory
   so a test stays with the code it covers, and balanced by line count. Use fewer shards
   when the test code is small (one shard under roughly 2000 lines). Never split one
   package or test file across shards.
4. State the shard list, test file and line counts, and the suite result in a few lines.

## 2. Reviewers

Start one reviewer per shard, all at once, the same way as step 3 of the main workflow.
Each gets this brief:

```
Review only. Leave every file unchanged: no edits, formatters, commits,
pushes, PR comments, subagents, or other reviewers.
Repo: <abs path>  Lens: tests  Shard: <n> of <total>
Files: <test files in this shard>
Suite: <command and result, known failing/skipped/flaky tests>
Read each test and the code it exercises. Judge whether the test would
fail if the behavior it claims to cover broke, and whether another test
already covers the same thing.
<tests checklist below>
Reply with only:
VERDICT: APPROVE or CHANGES
T<shard>.<n> [delete|merge|strengthen|deflake|document] <file>:<line> <test name>.
  Covers: <behavior, or "nothing">. Evidence: <why>. Fix: <smallest fix>
```

Ids use the `T` prefix and the shard number, so they stay unique across shards.

## Checklist

Low-value signals:

- Asserts nothing, or only that no error or panic occurred when that is not the behavior
  under test.
- Tests the mock: asserts on values a stub was just configured to return, or that a mock
  was called, without checking any outcome of the code under test.
- Recomputes the expected value with the same logic as the code under test.
- Tests the language, standard library, or a framework: plain getters and setters,
  constructors that only assign fields, struct literals, enum string values.
- Duplicates another test, or adds table cases that hit the same branch with no new
  boundary or input class.
- Weak assertions where an exact value matters: not nil, non-empty, length greater than
  zero, substring present.
- Large snapshot or golden output that covers no specific behavior and gets updated
  without review.
- Coupled to implementation details (private call order, exact log text, internal
  struct layout), so refactors break it while behavior stays correct.
- Flaky or slow by construction: sleeps, wall clock, real network, random order, shared
  global state.
- Disabled or skipped with no reason or linked issue, commented-out tests, or tests for
  code that no longer exists.
- Name or comment says it checks something the body does not.

Value signals, which argue for keeping a test:

- Pins a past bug (a regression test), even if it looks trivial.
- Covers a boundary, error path, or input class nothing else covers.
- Is the only coverage of a code path, contract, or public API behavior.
- Exercises integration between modules, or an invariant that is easy to break.

Actions:

- **delete**: no value signal, and removing it loses no unique coverage.
- **merge**: fold into the named existing test or table, keeping any unique case.
- **strengthen**: keep it, but assert the real outcome. Name the assertion.
- **deflake**: keep it, but make it deterministic (fake clock, waits on conditions,
  local fixtures). Name the change.
- **document**: it has value that is not obvious from reading it. Say what behavior it
  covers and why it exists (the bug, contract, or edge case).

## 3. Decide and apply

You judge every finding against the code, as in step 4 of the main workflow:

- Before a **delete** or **merge**, confirm the test adds no unique coverage. Read the
  remaining tests, and when the toolchain makes it cheap, compare package coverage
  before and after (for example `go test -coverprofile`). A drop in coverage of real
  logic means the test stays.
- When a test has real value that a reviewer missed, or that was hard to see, keep it
  and add or rewrite its comment: what behavior it covers, and why it exists (the bug,
  issue, contract, or edge case). Do not restate the code. Follow the project's comment
  conventions.
- Prefer **strengthen** or **deflake** over delete when the behavior is worth covering.
- Do not change production code in this tier, except a trivial seam needed to deflake a
  test. List anything larger as a follow-up.

Re-run the full suite after the edits. Every test that passed before must still pass,
and no previously passing package may fail. Revert an edit rather than fix production
code to make it pass.

One round. Run a second round only on a shard whose findings are still disputed, or when
the user asks.

## 4. Report

Use the main report format. In the Review item, give `tests tier`, the shard count, and
one line of totals: deleted, merged, strengthened, deflaked, documented. List each in
**Fixed** with its id and test name. Coverage changes, if measured, go in **Checks**.
