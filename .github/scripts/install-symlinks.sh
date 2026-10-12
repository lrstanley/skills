#!/usr/bin/env bash
# installs this repository (a single agent plugin, see plugin.json) locally:
#
#   - symlinks the repo root into ${AGENT_PLUGINS_HOME:-~/.agents/plugins}/<plugin name>.
#   - if the cursor cli (agent) is available, adds this repository as a cursor marketplace
#     (or re-indexes it if already added). cursor indexes from the git remote, so changes
#     must be pushed first. installing the plugin itself is done from cursor's customize page.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
plugins_home="${AGENT_PLUGINS_HOME:-${HOME}/.agents/plugins}"
legacy_skills_home="${HOME}/.agents/skills"
manifest="${repo_root}/plugin.json"
cursor_marketplace_manifest="${repo_root}/.cursor-plugin/marketplace.json"

if ! command -v jq >/dev/null 2>&1; then
    echo "error: jq is required to read ${manifest}" >&2
    exit 1
fi

if [[ ! -f ${manifest} ]]; then
    echo "error: plugin manifest not found: ${manifest}" >&2
    exit 1
fi

plugin_name="$(jq -er '.name' "${manifest}")"
target="${plugins_home}/${plugin_name}"

# prior versions of this script linked each skill individually into
# ~/.agents/skills. those links are stale now that skills live in the plugin (and
# would cause duplicate skills), so remove any link that points back into this repo.
if [[ -d ${legacy_skills_home} ]]; then
    for link in "${legacy_skills_home}"/*; do
        if [[ ! -L ${link} ]]; then
            continue
        fi
        link_target="$(readlink "${link}")"
        if [[ ${link_target} == "${repo_root}" || ${link_target} == "${repo_root}/"* ]]; then
            rm "${link}"
            echo "removed legacy skill link $(basename "${link}")"
        fi
    done
fi

mkdir -p "${plugins_home}"

if [[ -L ${target} ]]; then
    rm "${target}"
elif [[ -e ${target} ]]; then
    echo "error: ${target} exists and is not a symlink" >&2
    exit 1
fi

ln -s "${repo_root}" "${target}"
echo "linked ${plugin_name} -> ${target}"

# cursor install, via the cli. cursor can't load plugins from symlinks, so it uses a
# git-backed marketplace instead.
if ! command -v agent >/dev/null 2>&1; then
    echo "skipping cursor marketplace: agent cli not found"
    exit 0
fi

if [[ ! -f ${cursor_marketplace_manifest} ]]; then
    echo "skipping cursor marketplace: ${cursor_marketplace_manifest} not found"
    exit 0
fi

marketplace_name="$(jq -er '.name' "${cursor_marketplace_manifest}")"
marketplace_url="$(jq -er '.repository' "${manifest}")"

if agent plugin marketplace list --format json |
    jq -e --arg name "${marketplace_name}" 'any(.[]; .name == $name)' >/dev/null; then
    echo "updating cursor marketplace ${marketplace_name}"
    cursor_cmd=(update "${marketplace_name}")
else
    echo "adding cursor marketplace ${marketplace_name} (${marketplace_url})"
    cursor_cmd=(add "${marketplace_url}")
fi

if ! agent plugin marketplace "${cursor_cmd[@]}"; then
    echo "warning: failed to ${cursor_cmd[0]} cursor marketplace ${marketplace_name}" >&2
    exit 1
fi

echo "install the ${plugin_name} plugin from cursor's customize page, if not already installed"
