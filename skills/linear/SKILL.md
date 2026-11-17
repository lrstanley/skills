---
name: linear
description: Status and project-guidance rules for working on a Linear issue. Use when the user references a Linear issue (an ID like ENG-123 or a Linear URL) and asks to implement, fix, or work on it, or when landing that work on the default branch.
license: MIT
metadata:
  author: https://github.com/lrstanley
  domain: devops
  triggers: linear, linear issue, issue status, in progress, mark done
  role: specialist
  scope: implementation
  output-format: report
  related-skills: apply-worktree
---

# Linear

Rules for moving a Linear issue through its statuses while you work on it. They
use the Linear MCP server. If it is unavailable, say so, then do the work
without status changes.

## Statuses and links

- Status names vary by team (`TODO`, `Todo`, ...). Match on the status type
  from `list_issue_statuses`: Backlog is `backlog`, Todo is `unstarted`, In
  Progress and In Review are `started`, Done is `completed`.
- An issue is **linked** when a GitHub pull request or branch is attached to it
  (an attachment in `get_issue`). The `gitBranchName` field is only Linear's
  suggested name and does not make an issue linked.
- Linear's GitHub integration owns a linked issue's status, so every status
  change below applies only to unlinked issues. Re-check right before each
  change: a PR may be attached mid-work, including one you create.

## Starting

1. Fetch the issue with `get_issue` and its discussion with `list_comments`.
2. If it belongs to a project, read the project description with
   `get_project` and follow its guidance alongside the issue. Done when you
   have read it or confirmed it is empty.
3. If the status is Backlog or Todo, set it to In Progress and remember that
   you moved it. Every other status stays as it is.

## Finishing

The work has landed when it reaches the default branch (`main` or `master`) and
its worktree, through a merge, cherry-pick, rebase, fast-forward, or
equivalent. Pushing does not matter. Commits only on a worktree or feature
branch, or an apply that failed or hit conflicts, have not landed: leave the
issue In Progress and say so.

Set an issue to Done only when every condition holds:

- You implemented it directly in this work; issues merely touched or mentioned
  stay as they are.
- It is unlinked.
- Its status is In Progress, and you moved it there in Starting step 3.
- The work has landed.
- It is fully complete. Check the description, acceptance criteria,
  checklists, and sub-issues against what you built. If anything is missing,
  leave it In Progress, list the gaps, and ask the user before setting Done.

## Reporting

Whenever a rule above blocks a status change, say which rule and why in one
line.
