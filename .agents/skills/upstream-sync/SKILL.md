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

## Output

Per repo: one line (`unchanged`, or what was added/changed/removed and in which file). Then list
anything uncertain that needs a human decision.
