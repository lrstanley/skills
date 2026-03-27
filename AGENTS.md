<!--
  Adapted from & credit to: https://github.com/Jeffallan/claude-skills/blob/main/CLAUDE.md
-->

# Agent Skills Project Configuration

> This file governs an agent's behavior when working on the skills repository.

---

## Skill Authorship Standards

Skills follow the [Agent Skills specification](https://agentskills.io/specification).
This section covers project-specific conventions that go beyond the base spec.

### The Description Trap

**Critical:** Never put process steps or workflow sequences in descriptions. When
descriptions contain step-by-step instructions, agents follow the brief description
instead of reading the full skill content. This defeats the purpose of detailed
skills.

Brief capability statements (what it does) and trigger conditions (when to use it)
are both appropriate. Process steps (how it works) are not.

**BAD - Process steps in description:**

```yaml
description: Use for debugging. First investigate root cause, then analyze
patterns, test hypotheses, and implement fixes with tests.
```

**GOOD - Capability + trigger:**

```yaml
description: Diagnoses bugs through root cause analysis and pattern matching.
Use when encountering errors or unexpected behavior requiring investigation.
```

**Format:** `[Brief capability statement]. Use when [triggering conditions].`

Descriptions tell WHAT the skill does and WHEN to use it. The SKILL.md body tells HOW.

---

### Frontmatter Requirements

Per the [Agent Skills specification](https://agentskills.io/specification), only
`name` and `description` are top-level required fields. Custom fields go under
`metadata`.

```yaml
---
name: skill-name-with-hyphens
description: [Brief capability statement]. Use when [triggering conditions] - max 1024 chars
license: MIT
metadata:
  author: https://github.com/lrstanley
  version: "1.0.0"
  domain: frontend
  triggers: keyword1, keyword2, keyword3
  role: specialist
  scope: implementation
  output-format: code
  related-skills: foo-bar, baz-qux
---
```

**Top-level fields (spec-defined):**

- `name`: Letters, numbers, and hyphens only (no parentheses or special characters)
- `description`: Maximum 1024 characters. Capability statement + trigger conditions.
  No process steps.
- `license`: Always `MIT` for this project
- `allowed-tools`: Space-delimited tool list (only on skills that restrict tools)

**Metadata fields (project-specific):**

- `author`: GitHub profile URL of the skill author.
- `version`: Semantic version string (quoted, e.g., `"1.0.0"`).
- `domain`: Category from the domain list below.
  - `language`
  - `backend`
  - `frontend`
  - `infrastructure`
  - `api-architecture`
  - `quality`
  - `devops`
  - `security`
  - `data-ml`
  - `platform`
- `triggers`: Comma-separated searchable keywords.
- `role`:
  - `specialist`
  - `expert`
  - `architect`
  - `engineer`
- `scope`:
  - `implementation`
  - `review`
  - `design`
  - `system-design`
  - `testing`
  - `analysis`
  - `infrastructure`
  - `optimization`
  - `architecture`
- `output-format`:
  - `code`
  - `document`
  - `report`
  - `architecture`
  - `specification`
  - `schema`
  - `manifests`
  - `analysis`
  - `analysis-and-code`
  - `code+analysis`
- `related-skills`:
  - Comma-separated skill directory names (e.g., `foo-bar, baz-qux`).
  - Must resolve to existing skill directories.

---

### Reference File Standards

Reference files follow the [Agent Skills specification](https://agentskills.io/specification).
No specific headers are required.

**Guidelines:**

- 100-600 lines per reference file.
- Keep files focused on a single topic.
- Complete, working code examples with necessary types.
- Cross-reference related skills where relevant.
- Include "when to use" and "when not to use" guidance.
- Practical patterns over theoretical explanations.

### Framework Idiom Principle

Reference files for framework-specific skills must reflect the idiomatic best practices
of that framework, not generic patterns applied uniformly across all skills. If a
framework provides a built-in mechanism (e.g., global error handling, middleware,
dependency injection), reference examples should use it rather than duplicating
that behavior manually. Each framework's conventions for error handling, architecture,
and code organization take precedence over cross-project consistency.

---

### Progressive Disclosure Architecture

**Tier 1 - SKILL.md (~80-100 lines)**

- Role definition and expertise level.
- When-to-use guidance (triggers).
- Core workflow (5 steps).
- Constraints (MUST DO / MUST NOT DO).
- Routing table to references.

**Tier 2 - Reference Files (100-600 lines each)**

- Deep technical content.
- Complete code examples.
- Edge cases and anti-patterns.
- Loaded only when context requires.

**Goal:** 50% token reduction through selective loading.

---

## Project Workflow

### When Creating New Skills

1. Check existing skills for overlap
2. Write SKILL.md with capability + trigger description (no process steps)
3. Create reference files for deep content (100+ lines)
4. Add routing table linking topics to references
5. Test skill triggers with realistic prompts
6. Update SKILLS_GUIDE.md if adding new domain

### When Modifying Skills

1. Read the full current skill before editing
2. Maintain capability + trigger description format (no process steps)
3. Preserve progressive disclosure structure
4. Update related cross-references
5. Verify routing table accuracy
