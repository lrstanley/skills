---
name: apply-worktree
description: Land the current git worktree's commits onto the main worktree's default branch, verify, and clean up. Use for /apply-worktree.
disable-model-invocation: true
license: MIT
metadata:
  author: https://github.com/lrstanley
  version: "1.0.0"
  domain: devops
  triggers: worktree, apply worktree, land changes, merge back, cleanup worktree
  role: engineer
  scope: implementation
  output-format: report
---

Land this worktree's work onto the main worktree's default branch, then clean up.

1. **Commit**: if the worktree has uncommitted changes, commit them following the repo's commit conventions. Done when `git status --porcelain` is empty.
2. **Locate**: find the main worktree (first entry of `git worktree list`) and its default branch (`master` or `main`). Done when the main worktree is on that branch with a clean tree; if not, stop and ask.
3. **Apply**: rebase the worktree branch onto the default branch, then fast-forward the default branch in the main worktree (`git -C <main> merge --ff-only <branch>`). Resolve rebase conflicts yourself; stop and ask if the intent of a conflict is unclear.
4. **Confirm**: done when `git -C <main> branch --contains <branch-tip>` lists the default branch and `git -C <main> status` is clean.
5. **Clean up**: from the main worktree, run `git worktree remove <worktree>` and `git branch -d <branch>`. If either is denied or refused, leave it in place and say what remains.

Report the commits applied and what was removed or left behind. Pushing is out of scope.
