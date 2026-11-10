---
name: review
description: Review a change with parallel read-only reviewers picked by its size and risk, fix the real findings, and loop until only nits remain. Also offers an on-demand tests tier that finds low-value tests across a repository. Use for /review, or /review tests when cleaning up, pruning, or auditing tests.
disable-model-invocation: true
license: MIT
metadata:
  author: https://github.com/lrstanley
  domain: quality
  triggers: review, code review, review loop, reviewers, correctness, security, structure, simplify, performance, test cleanup, test quality, prune tests, purge tests, useless tests
  role: engineer
  scope: review
  output-format: code+analysis
  related-skills: simplify, nuclear-review, security-audit, babysit-pr
---

# Review

Run read-only reviewers over a change, judge their findings yourself, fix the
real ones with the smallest change, and repeat until only nits remain. You
are the only one who edits. Reviewers report.

The user may add arguments: a scope, a model, a round count, or lenses to add
or skip. Their arguments override every default below.

## Budget

| Tier    | Change                                                     | Lenses                                           | Rounds |
| ------- | ---------------------------------------------------------- | ------------------------------------------------ | ------ |
| Trivial | docs, config, renames, a few lines of obvious logic        | correctness                                      | 1      |
| Normal  | most feature and fix work                                  | correctness, structure, cleanup, + performance   | 3      |
| Risky   | security, permissions, auth, data loss, state/concurrency  | all that apply, security checklist on            | 3 to 5 |
| Tests   | on request only: clean up, prune, audit, or refactor tests | tests, one reviewer per shard (max 3), run alone | 1      |

The **tests tier** is never picked by triage. It runs only when the user asks to clean
up, purge, prune, audit, or refactor tests (or passes `tests`), runs by itself without
the other lenses, and covers the whole repository or the paths given instead of a diff.
For that run, follow [references/tests-tier.md](references/tests-tier.md) in place of
steps 1-5 below; the reviewer models, ledger, and step 6 report still apply.

- Round 1 is full. Later rounds check only changed code and open findings.
- Go past 3 rounds only for a risky-tier change while a blocker or should in
  that area stays open with evidence, or when the user asks.
- Stop early when a round returns only nits. Nits, and comment, doc, or
  format-only fixes, need no new round.
- Reviewers never start subagents or other reviewers. One reviewer per lens.
- Keep a **ledger**: id, lens, severity, outcome, one-line reason, and usage if
  returned. Never guess usage.

## Reviewer models

Reviewers read and judge, so a lighter model does the job. Use the model the
user names. Otherwise:

1. In T3 Code, the latest GPT Sol at medium effort via `delegate_task`. A
   second provider gives a view independent of yours.
2. Elsewhere, or when Sol is unavailable, the latest Sonnet at medium effort
   via the native subagent tool.

Raise effort to high for the risky tier, and for a complex normal-tier change:
intricate logic or state, a refactor across modules, or a large diff. Read
model IDs from what the client lists, never hardcode them. If a model the user named is unavailable, report
it and stop rather than substituting. Note provider, model, and effort in the
ledger only when the client exposes them.

## 1. Scope

Run `git status --short`. Leave unrelated changes alone: no stash, discard,
or reformat. Scope, first match wins:

1. What the user gave: paths, commits, a range, a PR, or "uncommitted".
2. A PR: `gh pr view <n> --json baseRefName,headRefOid`; base is
   `git merge-base HEAD origin/<baseRefName>`.
3. A branch: base is `git merge-base HEAD origin/<default-branch>`.
4. On the default branch: uncommitted changes against `HEAD`, or `HEAD~1` if
   the tree is clean.

The change is base to working tree, untracked files included. Use one diff
command for every round. Write the intent and what is out of scope in 1-2
sentences. Run the checks that cover the change and note any that are missing
or were failing before. Done when the diff holds the change and nothing else.

## 2. Triage

Pick the tier and lenses from the Budget table, using the lens triggers in
[references/lenses.md](references/lenses.md). When in doubt between tiers,
take the higher one. State the tier, lenses, and budget in one line.

## 3. Start reviewers

Start every chosen lens at once, one reviewer each, using the brief in
[references/lenses.md](references/lenses.md). Leave scoped files untouched
while reviewers run.

- **T3 Code**: call `orchestrator_capabilities` once, then one `delegate_task`
  per reviewer (`role: "review"`, `mode: "async"`, new `clientRequestId` per
  round). Every round is a fresh `delegate_task`. Wait for the notices.
- **Claude Code**: one `Agent` call per reviewer, all in one message, in the
  foreground, with `model` and `effort` set.
- **Codex**: `spawn_agent` per reviewer, then wait.

A timeout, error, or empty reply is not approval: cancel it, confirm it
stopped, and restart that one reviewer with the ledger.

## 4. Answer findings

Check every finding and its severity against the code yourself. A rare case,
another path, or a small cost is a nit, whatever label it came with.

- **Agree**: fix it with the smallest change. Prefer delete or narrow over a
  new guard, lock, cache, option, or helper. A restructure that deletes
  complexity counts as small. Add one focused test only when the intent needs
  it and it fails without the fix.
- **Same root cause**: when several findings share one cause, fix the cause
  once, from first principles, instead of patching each finding.
- **Disagree**: record why, with evidence (file:line, test, output).
- **Nit**: fix it only when it is a few lines, sits in hunks the diff already
  changes, and needs no new file, test, or follow-on edit elsewhere. Decline
  the rest in one line. A nit fix never starts a new round.
- **Out of scope**: decline in one line. Keep pre-existing problems outside
  the diff as follow-ups.

Breaking changes are fine when the project is unreleased or the API is
internal (unexported, internal package, application code). For a published
API, list the breaking fix as a follow-up instead of making it.

Re-run the checks and `git diff --shortstat <base>`. If the fixes grew the
diff, cut first. Agreeing just to end the loop is a failure. Done when every
finding in the ledger has an outcome.

## 5. Next round

Start one only if budget remains and a blocker or should is open, or the
fixes changed behavior code. Re-run only the lenses with open findings or
whose area the fixes touched, plus correctness whenever behavior changed.
Send each the round 1 brief, the ledger, and the hunks you changed since the
last round. Ask it to mark each old id `resolved` or `still open: <reason>`.

## 6. Stop and report

**Done**: every reviewer approves the current diff, or returns only nits, and
no blocker or should is open. **Stuck**: a finding is still disputed after
two replies, or the budget ran out. Show both sides in 2-3 lines each and let
the user decide. Running out of budget is not approval.

Report as one markdown list, rendered directly, never inside a code fence.
One top-level item per group, each with its emoji and bold label, and at most
one nested level beneath it. One line per finding, no further detail. Omit a
group that has nothing in it, except Review and Checks.

```markdown
- 🔍 **Review**: <tier> (<why>), <N> rounds, <model and effort>
  - Lenses: <lenses>
  - Diff: <before> -> <after> lines
- 🧪 **Checks**: <what ran and passed; failures or pre-existing warnings>
- ✅ **Fixed**
  - `<id>` `<file>:<line>` <what changed>
- 🚫 **Declined**
  - `<id>` <one-line reason>
- ⚠️ **Open**
  - `<id>` <both sides, briefly>
- 📌 **Follow-ups**
  - <out-of-scope or breaking item worth tracking>
- 🧹 **Nits**: <fixed> fixed, <declined> declined
  - `<id>` <what changed, or why declined>
```

After the list, add at most 2-3 short sentences for what the list cannot
carry, such as a new test or a side effect of a fix. End with the commit
state.

Leave commits, pushes, and PR comments to the user's request.
