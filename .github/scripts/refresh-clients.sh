#!/usr/bin/env bash
# refreshes the installed copies of this plugin in Claude Code, Codex, and Cursor, so newly pushed
# skills show up without reinstalling. both clients install from the git remote, so push first.
#
#   - claude code: refreshes the marketplace clone, then updates the plugin (restart claude
#     code afterwards to apply).
#   - codex: refreshes the marketplace clone, then reinstalls the plugin from it (start a new
#     codex session afterwards to apply).
#   - cursor: re-indexes the marketplace, then verifies it is tracking the remote's HEAD. if it
#     is stuck on an older commit, the marketplace was added pinned to a commit, and needs a
#     remove + add (the plugin must then be reinstalled from cursor's customize page).
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
manifest="${repo_root}/plugin.json"
cursor_marketplace_manifest="${repo_root}/.cursor-plugin/marketplace.json"
claude_marketplace_manifest="${repo_root}/.claude-plugin/marketplace.json"
codex_marketplace_manifest="${repo_root}/.agents/plugins/marketplace.json"
# names this plugin was previously published under.
legacy_plugin_names=(lrstanley-skills)

for bin in jq git; do
    if ! command -v "${bin}" >/dev/null 2>&1; then
        echo "error: ${bin} is required" >&2
        exit 1
    fi
done

plugin_name="$(jq -er '.name' "${manifest}")"
repository="$(jq -er '.repository' "${manifest}")"
remote_head="$(git ls-remote "${repository}" HEAD | cut -f1)"
local_head="$(git -C "${repo_root}" rev-parse HEAD)"

if [[ ${remote_head} != "${local_head}" ]]; then
    echo "warning: local HEAD (${local_head:0:7}) differs from remote HEAD (${remote_head:0:7}), push first" >&2
fi

if command -v claude >/dev/null 2>&1 && [[ -f ${claude_marketplace_manifest} ]]; then
    marketplace="$(jq -er '.name' "${claude_marketplace_manifest}")"
    echo "claude: updating marketplace ${marketplace}"
    claude plugin marketplace update "${marketplace}"

    installed="$(claude plugin list --json | jq -r '.[].id')"
    for legacy_name in "${legacy_plugin_names[@]}"; do
        if grep -qxF "${legacy_name}@${marketplace}" <<<"${installed}"; then
            echo "claude: uninstalling legacy plugin ${legacy_name}@${marketplace}"
            claude plugin uninstall "${legacy_name}@${marketplace}"
        fi
    done

    if grep -qxF "${plugin_name}@${marketplace}" <<<"${installed}"; then
        claude plugin update "${plugin_name}@${marketplace}"
    else
        echo "claude: installing ${plugin_name}@${marketplace}"
        claude plugin install "${plugin_name}@${marketplace}"
    fi
else
    echo "skipping claude: cli or ${claude_marketplace_manifest} not found"
fi

if command -v codex >/dev/null 2>&1 && [[ -f ${codex_marketplace_manifest} ]]; then
    marketplace="$(jq -er '.name' "${codex_marketplace_manifest}")"
    if codex plugin marketplace list --json |
        jq -e --arg name "${marketplace}" 'any(.marketplaces[]; .name == $name)' >/dev/null; then
        echo "codex: updating marketplace ${marketplace}"
        codex plugin marketplace upgrade "${marketplace}"

        installed="$(codex plugin list --marketplace "${marketplace}" --json | jq -r '.installed[].pluginId')"
        for legacy_name in "${legacy_plugin_names[@]}"; do
            if grep -qxF "${legacy_name}@${marketplace}" <<<"${installed}"; then
                echo "codex: uninstalling legacy plugin ${legacy_name}@${marketplace}"
                codex plugin remove "${legacy_name}@${marketplace}"
            fi
        done

        # add reinstalls from the refreshed marketplace clone, so it doubles as an update.
        echo "codex: installing ${plugin_name}@${marketplace}"
        codex plugin add "${plugin_name}@${marketplace}"
    else
        echo "skipping codex: marketplace ${marketplace} not added, run install-symlinks.sh first"
    fi
else
    echo "skipping codex: cli or ${codex_marketplace_manifest} not found"
fi

if command -v agent >/dev/null 2>&1 && [[ -f ${cursor_marketplace_manifest} ]]; then
    marketplace="$(jq -er '.name' "${cursor_marketplace_manifest}")"
    echo "cursor: updating marketplace ${marketplace}"
    agent plugin marketplace update "${marketplace}"

    indexed_ref="$(agent plugin marketplace list --format json |
        jq -r --arg name "${marketplace}" '.[] | select(.name == $name) | .gitRef // empty')"

    if [[ ${indexed_ref} != "${remote_head}" ]]; then
        cat >&2 <<EOF
warning: cursor marketplace ${marketplace} is indexed at ${indexed_ref:0:7}, remote HEAD is ${remote_head:0:7}.
it is likely pinned to a commit. to fix (then reinstall the plugin from cursor's customize page):

  agent plugin marketplace remove ${marketplace}
  agent plugin marketplace add ${repository} --git-ref master
EOF
        exit 1
    fi
    echo "cursor: marketplace is at ${indexed_ref:0:7}, update the installed plugin from cursor's customize page"
    echo "cursor: if a plugin named ${legacy_plugin_names[*]} is still installed, uninstall it and install ${plugin_name} instead"
else
    echo "skipping cursor: cli or ${cursor_marketplace_manifest} not found"
fi
