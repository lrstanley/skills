#!/usr/bin/env bash
# installs this repository (a single agent plugin, see plugin.json) locally:
#
#   - symlinks the repo root into ${AGENT_PLUGINS_HOME:-~/.agents/plugins}/<plugin name>.
#   - if the codex cli is available, adds this repository as a codex marketplace (or
#     refreshes it if already added), and installs the plugin from it. codex installs from
#     the git remote, so changes must be pushed first.
#   - if the cursor cli (agent) is available, adds this repository as a cursor marketplace
#     (or re-indexes it if already added). cursor indexes from the git remote, so changes
#     must be pushed first. installing the plugin itself is done from cursor's customize page.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
plugins_home="${AGENT_PLUGINS_HOME:-${HOME}/.agents/plugins}"
legacy_skills_home="${HOME}/.agents/skills"
manifest="${repo_root}/plugin.json"
cursor_marketplace_manifest="${repo_root}/.cursor-plugin/marketplace.json"
codex_marketplace_manifest="${repo_root}/.agents/plugins/marketplace.json"
# names this plugin was previously published under.
legacy_plugin_names=(lrstanley-skills)

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

# remove links left over from previous plugin names, if they point back into this repo.
for legacy_name in "${legacy_plugin_names[@]}"; do
    link="${plugins_home}/${legacy_name}"
    if [[ ${legacy_name} != "${plugin_name}" && -L ${link} && $(readlink "${link}") == "${repo_root}" ]]; then
        rm "${link}"
        echo "removed legacy plugin link ${legacy_name}"
    fi
done

if [[ -L ${target} ]]; then
    rm "${target}"
elif [[ -e ${target} ]]; then
    echo "error: ${target} exists and is not a symlink" >&2
    exit 1
fi

ln -s "${repo_root}" "${target}"
echo "linked ${plugin_name} -> ${target}"

# codex install, via the cli. codex copies the plugin into its own cache on install, and a
# local marketplace would copy the whole checkout (including ignored files), so it uses a
# git-backed marketplace instead. set -e does not apply inside a function called with ||,
# so each step returns on failure explicitly.
install_codex() {
    local marketplace repository existing_source

    if ! command -v codex >/dev/null 2>&1; then
        echo "skipping codex marketplace: codex cli not found"
        return 0
    fi

    if [[ ! -f ${codex_marketplace_manifest} ]]; then
        echo "skipping codex marketplace: ${codex_marketplace_manifest} not found"
        return 0
    fi

    marketplace="$(jq -er '.name' "${codex_marketplace_manifest}")" || return 1
    repository="$(jq -er '.repository' "${manifest}")" || return 1
    existing_source="$(codex plugin marketplace list --json |
        jq -r --arg name "${marketplace}" '.marketplaces[] | select(.name == $name) | .marketplaceSource.sourceType')" || return 1

    case "${existing_source}" in
        "")
            echo "adding codex marketplace ${marketplace} (${repository})"
            codex plugin marketplace add "${repository}" --ref master || return 1
            ;;
        git)
            echo "updating codex marketplace ${marketplace}"
            codex plugin marketplace upgrade "${marketplace}" || return 1
            ;;
        *)
            echo "warning: codex marketplace ${marketplace} is a ${existing_source} source, not git. to switch:" >&2
            echo "  codex plugin marketplace remove ${marketplace} && ${BASH_SOURCE[0]}" >&2
            return 1
            ;;
    esac

    echo "codex: installing ${plugin_name}@${marketplace}"
    codex plugin add "${plugin_name}@${marketplace}" || return 1
    echo "codex: start a new codex session to load the plugin"
}

install_codex || echo "warning: failed to install the codex plugin" >&2

# cursor install, via the cli. cursor can't load plugins from symlinks, so it uses a
# git-backed marketplace instead. set -e does not apply inside a function called with ||,
# so each step returns on failure explicitly.
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
