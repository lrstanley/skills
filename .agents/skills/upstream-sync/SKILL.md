---
name: upstream-sync
description: Checks upstream repos and packages referenced by the skills (github.com/lrstanley first, then other libraries and tools) for new features, changes, and deprecations, and updates skill docs to match. Use when asked to sync, refresh, or audit skills against upstream changes.
license: MIT
---

# Upstream sync

Repo-only (not shipped in the plugin). Keeps `skills/` current with the projects it documents.

**State:** `.upstream-sync.json` at the repo root (gitignored). Map of `<owner/repo>` to
`{"sha": "<last checked commit>", "tag": "<last release>", "checked": "<ISO date>"}`. Missing file
or entry means first run for that repo: use the latest release (or last ~30 commits) as the baseline
instead of reading all history.

## Steps

1. **Collect references:** grep `skills/` and `README.md` for `github.com/<owner>/<repo>` and Go import paths
   (`go.dev`/`pkg.go.dev` links, `import` blocks). Dedupe to a repo list. Do `lrstanley/*` first, then
   the rest. Skip `lrstanley/skills`, and skip skills synced via `remotes.yaml` (use `task up` for those).
   Always include `lrstanley/bloom` and `lrstanley/steep` (see **Docs-first libraries**).
   Check for moves: if `gh api repos/<o>/<r>` redirects or a Go package now lives in its own module (as
   steep did, from `lrstanley/x/term/steep` to `lrstanley/steep`), update every import path, link, and
   install command that uses the old location.
2. **Cheap check per repo** (parallelize; use `gh api`):
   - Compare HEAD sha and latest release tag to state. Unchanged: skip.
   - Changed: `gh api repos/<o>/<r>/compare/<old>...HEAD --jq '.files[].filename'` (names only), plus release
     notes (`gh release list` / `gh release view`) and `CHANGELOG`/`README` diffs.
   - Read the full diff only for files that matter: exported API, `README`, `docs/`, `examples/`, config,
     CLI flags. Ignore tests, CI, deps bumps, and internal refactors.
3. **Decide per finding** whether it belongs in a skill. Cover new public APIs/features, behavior or
   best-practice changes, and renames. Fix or remove docs for deprecated or removed APIs. Skip anything
   already documented or too minor for a skill.
4. **Edit** the owning skill, following `AGENTS.md` (progressive disclosure, reference file sizes, ASCII
   only, README table if scope changes). Verify new APIs against pkg.go.dev or source before documenting.
5. **Save state** for every repo checked (including no-change ones) only after its edits are done.
   Never commit.

## Docs-first libraries

Some libraries publish agent-oriented docs, so the skill only keeps a high-level map and points at them:

| Repo | Skill file | Docs indexes |
| --- | --- | --- |
| `lrstanley/bloom` | `skills/golang-tui/references/libraries/bloom.md` | `https://bloomfx.dev/llms.txt` |
| `lrstanley/steep` (steep, reel, reel CLI) | `skills/golang-tui/references/libraries/steep.md` | `https://getsteep.dev/llms.txt`, `/steep/llms.txt`, `/reel/llms.txt`, `/cli/llms.txt` |

For these:

- Diff the `llms.txt` indexes and `docs/content/` (page added, removed, or renamed) rather than reading
  every API change. A new docs page or package usually means a new line in the skill's feature map; a
  removed one means deleting that line or link.
- Keep the skill at the capability level: what the library covers, when to use it, and where the docs
  are. Do not copy option names, flags, signatures, or tables into the skill; link the docs page instead.
- Verify every link and docs URL in the skill still resolves (`curl -fsSI`).
- Check that code snippets in the skill, and in other golang-tui references that use these libraries
  (layout, dialogs, mouse, focus, testing, demo recording), still compile against the default branch.
  Update or shrink them instead of adding new detail.
- Keep the golang-tui `SKILL.md` defaults intact: bloom for layout/layers/input/motion, steep for tests,
  `reel session` for agents driving TUIs without steep tests. Update its routing table and triggers if a
  major capability is added or removed.

## Output

Per repo: one line (`unchanged`, or what was added/changed/removed and in which file). Then list
anything uncertain that needs a human decision.
