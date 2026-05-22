#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
skills_home="${HOME}/.agents/skills"

exclude_dirs=(
    ".github"
    ".vscode"
    ".cursor"
    "test-prompts"
)

is_excluded() {
    local name="$1"
    for excluded in "${exclude_dirs[@]}"; do
        if [[ ${name} == "${excluded}" ]]; then
            return 0
        fi
    done
    return 1
}

mkdir -p "${skills_home}"

for skill_dir in "${repo_root}"/*/; do
    dirname="$(basename "${skill_dir}")"

    if is_excluded "${dirname}"; then
        continue
    fi

    if [[ ! -f "${skill_dir}/SKILL.md" ]]; then
        continue
    fi

    target="${skills_home}/${dirname}"

    if [[ -L ${target} ]]; then
        rm "${target}"
    elif [[ -d ${target} ]]; then
        echo "warning: skipping ${dirname}: ${target} is a real directory" >&2
        continue
    fi

    ln -sf "${skill_dir%/}" "${target}"
    echo "linked ${dirname} -> ${target}"
done
