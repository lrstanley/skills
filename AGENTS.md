<!--
  Adapted from & credit to: https://github.com/Jeffallan/claude-skills/blob/main/CLAUDE.md
-->

# Agent Skills Project Configuration

> This file governs an agent's behavior when working on the skills repository.

---

## Plugin Layout

This repository is a single [Agent Plugin](https://agent-plugins.org/specification)
(spec v1.0.0), and also a [Cursor Plugin](https://cursor.com/docs/reference/plugins). The
repository root is the plugin root for both.

```text
.
├── plugin.json            # Agent Plugins manifest (portable: skills + MCP servers)
├── .claude-plugin/
│   └── marketplace.json   # Claude Code marketplace; the entry (source "./") is the plugin manifest
├── .cursor-plugin/
│   ├── plugin.json        # Cursor Plugin manifest (adds agents, rules, commands, hooks)
│   └── marketplace.json   # makes the repo a Cursor marketplace containing just this plugin
├── skills/                # every skill lives in skills/<skill-name>/SKILL.md
├── agents/                # Cursor custom agents (*.md)
└── mcp.json               # (optional) MCP servers, same spec version as plugin.json
```

- Skills are discovered only as immediate children of `skills/` (no nesting, and no
  skills outside of `skills/`). The skill directory name must match its `name`.
- `plugin.json` has a closed schema. Only `$schema`, `name`, `version`, `description`,
  `author`, `homepage`, `repository`, `license`, `keywords`, and `extensions` are allowed
  top-level fields. Client-specific manifest data goes under `extensions`.
- Keep `name`, `description`, and metadata in `.cursor-plugin/plugin.json`, the plugin
  entry in `.cursor-plugin/marketplace.json`, and the plugin entry in
  `.claude-plugin/marketplace.json` in sync with `plugin.json`. There is deliberately no
  `.claude-plugin/plugin.json`, so Claude Code uses the marketplace entry as the manifest.
  Validate with `claude plugin validate .`.
- The portable spec only defines skills and MCP servers. Other component types are
  client-specific. For Cursor, use `agents/`, `rules/`, `commands/`, and `hooks/` at the
  root (discovered automatically). Files for other clients belong in a top-level directory
  named for that client's reverse-domain namespace (e.g. `com.example.client/`).
- All files must resolve within the repository root. Do not add symlinks that point outside
  of it.
- Dev-only content (`.github/`, `.cursor/`, `test-prompts/`, `tmp/`) is not part of the
  plugin's components, and must never be referenced by skills or agents.
- `./.github/scripts/install-symlinks.sh` (`task`) symlinks the repo root into
  `~/.agents/plugins/<plugin name>`, and, when the Cursor `agent` CLI is present, runs
  `agent plugin marketplace add` (or `update`) for this repo. Cursor does not read
  `~/.agents/plugins`, and indexes from the git remote, so changes must be pushed first.

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
- Do not use em-dashes, smart quotes, or other non-ASCII characters for formatting.

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

### Remote Skills (`remotes.yaml`)

Some skills are synced from upstream Git repositories rather than authored directly in
this repo. **`remotes.yaml`** is the source of truth for which skills are remote-sourced
and how they are customized.

**Before modifying any skill, check `remotes.yaml` first.**

- If the skill directory (`skills/<name>/`) appears under a remote's `file_includes` `dest`
  entry, it is pulled from upstream. Direct edits to files in that directory will be
  overwritten on the next sync.
- If the remote entry lists `patches`, local customizations belong in `.github/patches/`.
  Add or edit patch files there, register them under `patches` in `remotes.yaml`, then
  re-sync with `task sync` (or `./.github/scripts/update-remotes.py --filter <remote-name>`).
- To bump an upstream remote to a newer commit, use `task up` (or
  `./.github/scripts/update-remotes.py --update`).

### When Creating New Skills

1. Check existing skills for overlap
2. Create `skills/<skill-name>/SKILL.md` with capability + trigger description (no
   process steps)
3. Create reference files for deep content (100+ lines)
4. Add routing table linking topics to references
5. Test skill triggers with realistic prompts
6. Add the skill to the **Skills** table in `README.md` (link to `SKILL.md`, one-line
   summary of capability and purpose)

### When Modifying Skills

1. Check `remotes.yaml` first to see if the skill is synced from upstream and/or patched
   (see **Remote Skills** above). Do not edit remote-synced skill files directly.
2. Read the full current skill before editing
3. Maintain capability + trigger description format (no process steps)
4. Preserve progressive disclosure structure
5. Update related cross-references
6. Verify routing table accuracy
7. Keep `README.md` **Skills** table in sync when changes are substantial: new or
   removed skills, renamed skill directories, or material shifts in what the skill
   is for (typically reflected in frontmatter `description` or core scope). Routine
   reference edits or typo fixes that do not change purpose do not require a README
   update.
