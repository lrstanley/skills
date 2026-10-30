---
name: file-pr
description: File a concise pull request that leads with the problem, not an inventory of changes. Use for /file-pr.
disable-model-invocation: true
license: MIT
metadata:
  author: https://github.com/lrstanley
  version: "1.0.0"
  domain: devops
  triggers: file pr, open pr, create pr, pull request, pr title, pr description
  role: engineer
  scope: implementation
  output-format: document
  related-skills: babysit-pr, leaving-gh-comments
# Adapted from https://github.com/t3dotgg/tstack/tree/main/skills/file-pr (MIT, Copyright (c) 2026 Theo Browne).
---

# File PR

1. **Check**: confirm no PR exists for this branch yet, and diff the branch
   against its base (usually `origin/master` or `origin/main`). Done when the
   diff contains the change the user asked for and nothing else.
2. **Title**: follow the repository's title conventions, taken from recently
   merged PRs and git history, since titles usually become commit messages.
   Write a concise, human-readable title that says why the change matters.
3. **Description**: open with the problem, in plain terms drawn from the user's
   original request, then briefly explain the solution. If the repository has a
   pull request template, fill it in the same way. End with the public model
   name and harness that made the changes, for example
   `Created with <model> in <harness>.`, including subagent models that wrote
   part of it. Use the model name the harness reports; if it reports none, name
   only the harness.
4. **Scrub**: check the title, description, quotes, and attachments for secrets
   and private details.
5. **Open**: open a ready-for-review PR (not a draft) so review bots run. Done
   when GitHub returns the PR URL.

## Examples

Title, BAD:

> ❌ perf(server): negotiate permessage-deflate on the websocket

Title, GOOD:

> ✅ perf(server): cut websocket frame size by 70%+ with gzipping

Description, BAD (implementation inventory):

> ❌ Removed implicit workspace carry-over from every "new thread" entry point (cmd+n / cmd+shift+o, sidebar v1/v2 buttons, command palette). New threads inherit only the project from context; branch, worktree, and env mode always come from the configured defaults. Deleted buildContextualThreadOptions, startNewThreadInProjectFromContext, and the v1 sidebar's seed-context machinery.

Description, GOOD (problem first):

> ✅ My "new worktree" default was ignored when starting new threads on existing worktrees. Super unintuitive. Now your preferences always apply.

## After filing

- If `gh pr create` fails because the GraphQL rate limit is used up, open the PR
  through REST:
  `gh api repos/<owner>/<repo>/pulls -f title=... -f head=... -f base=... -F body=@<file>`.
- If the user also asked to babysit the PR, read and follow
  `../babysit-pr/SKILL.md` relative to this skill's directory. If that file is
  missing, tell the user to run `/babysit-pr`.
- Post a follow-up PR comment only when the user's request needs one, following
  the `leaving-gh-comments` skill.
