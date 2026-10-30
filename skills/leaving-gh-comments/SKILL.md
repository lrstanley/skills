---
name: leaving-gh-comments
description: Formats comments an agent posts on GitHub on the user's behalf, with attribution and a secrets check. Use when posting, replying to, or resolving GitHub issue, PR, or review comments.
license: MIT
metadata:
  author: https://github.com/lrstanley
  version: "1.0.0"
  domain: devops
  triggers: github comment, pr comment, review comment, reply to reviewer, reply to bot, issue comment
  role: specialist
  scope: implementation
  output-format: document
  related-skills: babysit-pr, file-pr, modernize
# Adapted from https://github.com/t3dotgg/tstack/tree/main/skills/leaving-pr-comments (MIT, Copyright (c) 2026 Theo Browne).
---

# Leaving GitHub Comments

## Scope

Applies to top-level issue and PR comments, inline review comments, replies to
bots or reviewers, and written explanations posted before resolving or
dismissing feedback. PR descriptions, commit messages, and text the user asked
to post verbatim without attribution are out of scope.

## Attribution line

Start every comment with exactly one attribution line, then a blank line, then
the comment:

```md
🤖 *<model> responding on behalf of <user>*

Actual comment starts here.
```

- `<model>` is the verified public name of the model that wrote the comment. If
  the harness exposes none, use the harness name instead of guessing.
- `<user>` is the user's name or GitHub login.
- The attribution line is the comment's only header and only signature: plain
  text after it, with no heading, horizontal rule, Setext underline, or footer.

## Body

- Lead with the conclusion.
- Cite the relevant code, behavior, check, or reproduction.
- Keep it to the substance, without thanks or status narration.
- Mark which statements are verified and which are judgment.

## Posting

1. Check the whole comment, including quoted text and attachments, for secrets
   and private details. The comment itself says nothing about this check.
2. Reread the final Markdown so quoting and blank lines render as intended.
3. Post it. Done when GitHub returns the comment or review URL.
4. Resolve a review thread only after its reply has posted.
