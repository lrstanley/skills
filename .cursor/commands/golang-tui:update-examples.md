---
description: >-
  Re-sync golang-tui Bubble Tea official examples reference from charmbracelet/bubbletea examples README
---

# /golang-tui:update-examples

**Goal:** Align `golang-tui/references/libraries/examples.md` with the current [Bubble Tea examples README](https://github.com/charmbracelet/bubbletea/blob/main/examples/README.md).

**Source of truth:** The README at `main` on GitHub -- not a local clone unless you are validating links.

## Steps

1. **Fetch the canonical README** (raw):

   `https://raw.githubusercontent.com/charmbracelet/bubbletea/main/examples/README.md`

2. **Parse structure:** Treat each `### `-level heading as one documented example. The following paragraph usually contains `` `dirname` `` naming the directory under `examples/`. Build an ordered list of `(heading title, directory name, descriptive sentence from the README)`.

3. **Compare to** `golang-tui/references/libraries/examples.md`:

   - **New** README section / example → add a matching `###` block in the same order as upstream. Each block must include:
     - **`Tree:`** link: `https://github.com/charmbracelet/bubbletea/tree/main/examples/<dirname>`
     - Short bullets naming **features and components** (Bubble Tea messages, `tea.Cmd` patterns, Bubbles packages, Lip Gloss, external libs like Glamour) -- **no full code blocks**; this file stays a map, not a tutorial.

   - **Removed** from README → remove the corresponding `###` section from the reference (unless the project explicitly keeps historical entries -- default is **delete** to stay aligned).

   - **Renamed directory or heavily rewritten blurb** → update the tree URL and bullets so they match the new README. If only wording changes slightly, adjust bullets minimally.

4. **Preserve file-level framing:** Keep the intro paragraph, the link to the GitHub README as the authoritative index, the pointer to this command path, and the **Scope note** at the bottom (refresh the "not every folder" wording if the README policy changes).

5. **Validate links:** Spot-check that each `examples/<dirname>` path exists on `main` (e.g. GitHub tree URL or API). If the README references a directory that does not exist yet, keep the README as source of truth and note the mismatch in your summary to the user.

## Output

- Brief summary of what changed (added / removed / updated sections).
- If nothing changed, say so explicitly.
