---
name: modernize
description: Bring a stale pull request up to date and decide whether it should still exist. Use for /modernize.
disable-model-invocation: true
license: MIT
metadata:
  author: https://github.com/lrstanley
  version: "1.0.0"
  domain: devops
  triggers: modernize, rebase pr, stale pr, old pr, revive pr, update pr branch
  role: engineer
  scope: implementation
  output-format: analysis-and-code
  related-skills: file-pr, babysit-pr, leaving-gh-comments
# Adapted from https://github.com/t3dotgg/tstack/tree/main/skills/modernize (MIT, Copyright (c) 2026 Theo Browne).
---

# Modernize

Modernize the idea, not just the branch. A clean rebase does not prove that the
PR still belongs in the product.

## Guardrails

- Treat existing worktree changes as user-owned. Use a disposable worktree when
  the active worktree is dirty or is being used for other work.
- Modernizing authorizes rebasing and updating the PR branch only. Merging,
  closing, changing the base branch, and expanding scope each need the user's
  explicit permission.
- Push a rebased branch only with `--force-with-lease` against the head SHA
  observed before the rebase.
- Post PR comments only when the user asked for one, following the
  `leaving-gh-comments` skill.

## Establish the PR's intent

Resolve the PR and record its URL, state, base, head repository and branch,
current head SHA, author, checks, and review state. Read the title, body, linked
issues, commits, review threads, and complete diff. State the smallest coherent
goal the PR was trying to accomplish before judging its implementation.

Fetch the latest remote base and PR head. Use the PR's actual base branch,
usually `master` or `main`, rather than trusting the local copy. Record the
merge base so the original PR and later base-branch changes can be compared
separately.

## Check what changed around it

Inspect commits and diffs added to the base branch since the PR diverged. Search
merged and open PRs when titles, code paths, or behavior suggest a replacement
or competing implementation.

Look beyond overlapping lines:

- Has the same user-facing problem already been solved?
- Did APIs, types, schemas, dependencies, or architectural boundaries change?
- Do both sides now claim ownership of the same behavior or invariant?
- Was the code being changed deleted, moved, or intentionally simplified?
- Would landing the PR restore an old behavior or create two ways to do the
  same thing?
- Is the original benefit still large enough to justify the maintenance cost?

A PR is current only when these questions come back clean. Git reporting no
conflicts answers none of them.

## Choose a disposition before pushing

Pick one:

- **MODERNIZE**: the goal is still useful and the implementation remains the
  right shape. Rebase, resolve conflicts, test, and update the branch.
- **REWORK**: the goal is still useful, but a mechanical rebase would preserve
  the wrong implementation. Explain the smallest credible rewrite and stop
  before pushing unless the user also asked for that rework.
- **CLOSE**: the PR is superseded, obsolete, directionally wrong, or no longer
  worth its cost. Cite concrete evidence and stop without rebasing. Close it
  only with explicit permission.

Be willing to recommend `CLOSE`. Age alone is not evidence, and sunk effort is
not a reason to keep a PR alive.

## Rebase without losing intent

For a `MODERNIZE` disposition:

1. Create a safe local branch or disposable worktree at the recorded PR head.
2. Rebase its commits onto the freshly fetched base branch.
3. Resolve each conflict according to the PR's current intent and the base
   branch's newer invariants. If a conflict reveals a product or architecture
   disagreement, stop and reconsider the disposition.
4. Compare the pre-rebase and post-rebase commit series with `git range-diff`
   and inspect the final diff. Done when no intentional behavior disappeared
   and no already-landed behavior was reintroduced.
5. Run the repository's focused checks for the touched area. Tell real failures
   apart from pre-existing or infrastructure failures.
6. Push with `--force-with-lease` tied to the previously observed remote head.
   If the lease fails, fetch and reassess.

## Report

Lead with `MODERNIZE`, `REWORK`, or `CLOSE` and the reason. Then summarize:

- meaningful changes on the base branch;
- conceptual conflicts, or confirmation that none were found;
- the rebase and push result, if performed;
- checks run and their results;
- the remaining decision or work, with a link to the PR.

Separate observed facts from judgment, and say what could not be verified.
