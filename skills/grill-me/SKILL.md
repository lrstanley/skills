---
name: grill-me
description: Interview the user relentlessly about a plan or design until reaching shared understanding, resolving each branch of the decision tree. Use when user wants to stress-test a plan, get grilled on their design, or mentions "grill me".
---

Interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

- Ask the questions one at a time.
- When using AskQuestion or similar structured question tools that support pre-configured options:
  - Prefix your recommended answer with `(preferred)` in the option label (e.g. `(preferred) Use Redis for caching`).
  - Put the recommended answer first in the options list.

If a question can be answered by exploring the codebase, explore the codebase instead.
