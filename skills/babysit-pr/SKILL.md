---
name: babysit-pr
description: Watch a pull request through CI and review bots, fix real findings, and keep it rebased until it is ready. Use for /babysit-pr.
disable-model-invocation: true
license: MIT
metadata:
  author: https://github.com/lrstanley
  version: "1.0.0"
  domain: devops
  triggers: babysit, babysit pr, watch pr, monitor pr, pr checks, ci failures, review bots, pr-wait
  role: engineer
  scope: implementation
  output-format: report
  related-skills: file-pr, modernize, leaving-gh-comments
# Adapted from https://github.com/t3dotgg/tstack/tree/main/skills/babysit-pr (MIT, Copyright (c) 2026 Theo Browne).
---

# Babysit PR

Carry one PR from its current state to the **merge gate**, handling every check
failure and review finding along the way.

## Waiting

Use exactly one watcher per PR: `watch_pull_request` in T3 Code, `pr-wait`
everywhere else. Both replace any hand-written polling or `sleep` loop. Every
watcher on a GitHub account shares one rate limit.

When an event needs no action, end your turn without a message.

### In T3 Code: `watch_pull_request`

Handle the existing checks and comments first. Then call
`watch_pull_request` and end your turn. T3 Code wakes you with a message when
a check fails, the required checks pass, someone comments or reviews, or the
branch conflicts.

- **Only the thread that owns the PR watches it.** A delegated child task (a
  reviewer, any `delegate_task` child) leaves watching to its parent, and every
  thread watches only PRs it is working on.
- **A wake is news, not a merge decision.** Check the merge gate yourself.
  `watch_pull_request` reports conflicts but not BEHIND, so check BEHIND too.
- **Unwatch when you hand off.** A watched thread stays in Working and out of
  the user's inbox. When you stop (ready, blocked, or asking the user a
  question), call `unwatch_pull_request` first. A merge or close ends the watch
  on its own.
- **"Stopped watching, could not read it"** usually means the rate limit is
  used up. See [GitHub rate limits](#github-rate-limits) before watching again.

### Everywhere else: `pr-wait`

Run `scripts/pr-wait` from this skill's directory, by absolute path:

```bash
pr-wait <pr> [--repo owner/name] [--until ready|green|any-change]
```

It prints one line per real event. It exits 0 when the `--until` condition is
met or the PR merges, 1 when it needs you (a required check failed, conflicts,
unresolved threads, PR closed), and 2 on bad input.

- `ready` (default): required checks green, Greptile or Macroscope reviewed the
  head, and no unresolved threads. Use this to babysit.
- `green`: required checks only. Use it when the repo has no Greptile or
  Macroscope.
- `any-change`: exit on the first event.

In Claude Code, run it with the Monitor tool (`timeout_ms: 3600000`), so each
line wakes you. Without a monitor, run it as one long foreground command. It
ends on its own.

Start it again after you push, after you handle an exit 1, and after a resume.
It remembers what it already reported, so nothing that arrived in between is
lost. If it reports that another pid already watches the PR, rely on that
watcher, and kill it only if its events are not reaching you.

## GitHub rate limits

`gh pr create`, `gh pr view`, and `gh pr checks` use GraphQL. Check it with
`gh api rate_limit --jq .resources.graphql`. If `remaining` is near 0, wait for
`reset` with one background command before watching again.

The REST limit is separate and usually still has room. Use
`gh api repos/<owner>/<repo>/pulls/<n>` to read a PR, and
`gh api repos/<owner>/<repo>/commits/<sha>/check-runs` for checks.

## Reviews

Act only on checks and comments newer than the latest push. Review bots are
useful but fallible: verify every finding against the source before changing
code. Fix real findings and CI failures, and tell repository failures apart from
infrastructure flakes.

- For a finding not worth addressing, reply with a written reason and resolve
  the thread. Every comment posted on the user's behalf follows the
  `leaving-gh-comments` skill.
- Attach screenshots or videos to replies when they show a fix and you can
  upload them.

Keep the PR at the size the user's goal needs. Review loops grow a PR one
cheap-looking fix at a time. Fix real bugs in the intended case, and prefer the
fix that deletes or narrows code. Decline the rest with a written reason and
list them as follow-ups: unneeded tests, guards for edge cases that do not
matter, extra integration or compatibility, and small performance costs.

## Base branch and merging

The **merge gate** passes when all of these hold on the latest head, right
after a `git fetch`:

- required checks are green;
- no review thread is unresolved;
- the PR is neither BEHIND nor DIRTY;
- no base commits that landed after the last green run touch this PR's files.

`pr-wait` reports base commits that touch this PR's files, and BEHIND or DIRTY
states. When the gate fails on the base branch (usually `master` or `main`),
rebase, push, and wait for green again. If an overlapping PR makes this one
obsolete, stop watching, report it to the user, and ask before closing the PR
unless closure was explicitly authorized.

Done when the merge gate passes (`pr-wait --until ready` exits 0, or the gate
checks out in T3 Code). Merge only if the user explicitly asked for it;
otherwise report that the PR is ready.
