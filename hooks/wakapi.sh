#!/usr/bin/env bash
# syncs ai coding activity to wakapi through wakatime-cli.
#
# exits 0 without doing anything unless all of these are true:
#   - $WAKATIME_HOME/.wakatime.cfg exists ($WAKATIME_HOME defaults to $HOME)
#   - [settings] api_url (or apiurl) is set, and its host is not wakatime.com
#   - an api key is available (api_key, api_key_vault_cmd, or WAKATIME_API_KEY)
#   - sync_ai_disabled is not true
#   - wakatime-cli is on PATH, $WAKATIME_CLI, or $WAKATIME_HOME/.wakatime/wakatime-cli
#
# the cli reads claude, cursor, and codex transcripts and sends ai coding heartbeats.
# syncs are detached and limited to one run per minute so hook storms stay cheap.
set -euo pipefail

plugin_name="lrstanley-skills"

lower() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

is_true() {
    case "$(lower "$1")" in
        1 | true | yes | on) return 0 ;;
        *) return 1 ;;
    esac
}

waka_home() {
    if [[ -n ${WAKATIME_HOME:-} ]]; then
        printf '%s' "$WAKATIME_HOME"
        return
    fi
    printf '%s' "$HOME"
}

config_file() {
    printf '%s/.wakatime.cfg' "$(waka_home)"
}

state_dir() {
    printf '%s/.wakatime' "$(waka_home)"
}

stamp_file() {
    printf '%s/lrstanley-skills-ai.stamp' "$(state_dir)"
}

sync_interval() {
    local interval="${WAKAPI_HOOK_INTERVAL:-60}"
    if [[ ! $interval =~ ^[0-9]+$ ]]; then
        interval=60
    fi
    printf '%s' "$interval"
}

# fills api_url, api_key, api_key_vault_cmd, sync_ai_disabled, and debug_setting.
# returns 1 when the config file is missing.
load_config() {
    api_url=""
    api_key=""
    api_key_vault_cmd=""
    sync_ai_disabled=""
    debug_setting=""

    local file line section key value
    file="$(config_file)"
    [[ -f $file ]] || return 1

    section=""
    while IFS= read -r line || [[ -n $line ]]; do
        line="${line%$'\r'}"
        line="${line#"${line%%[![:space:]]*}"}"
        [[ -z $line || $line == \#* || $line == \;* ]] && continue

        if [[ $line == \[* ]]; then
            section="${line#[}"
            section="${section%%]*}"
            section="$(lower "$section")"
            continue
        fi
        [[ $section == settings ]] || continue
        [[ $line == *=* ]] || continue

        key="${line%%=*}"
        value="${line#*=}"
        key="${key%"${key##*[![:space:]]}"}"
        key="$(lower "$key")"
        value="${value#"${value%%[![:space:]]*}"}"
        value="${value%"${value##*[![:space:]]}"}"

        if [[ $value == \"*\" ]]; then
            value="${value#\"}"
            value="${value%\"}"
        elif [[ $value == \'*\' ]]; then
            value="${value#\'}"
            value="${value%\'}"
        else
            value="${value%%#*}"
            value="${value%%;*}"
            value="${value%"${value##*[![:space:]]}"}"
        fi

        case "$key" in
            api_url | apiurl)
                [[ -z $api_url ]] && api_url=$value
                ;;
            api_key)
                [[ -z $api_key ]] && api_key=$value
                ;;
            api_key_vault_cmd)
                [[ -z $api_key_vault_cmd ]] && api_key_vault_cmd=$value
                ;;
            sync_ai_disabled)
                [[ -z $sync_ai_disabled ]] && sync_ai_disabled=$value
                ;;
            debug)
                [[ -z $debug_setting ]] && debug_setting=$value
                ;;
        esac
    done < "$file"
}

api_host() {
    local url="$1"
    url="${url#*://}"
    url="${url%%/*}"
    url="${url##*@}"
    url="${url%%:*}"
    url="${url#[}"
    url="${url%]}"
    lower "$url"
}

is_wakatime_cloud() {
    local host
    host="$(api_host "$1")"
    case "$host" in
        wakatime.com | *.wakatime.com) return 0 ;;
        *) return 1 ;;
    esac
}

configured() {
    load_config || return 1
    [[ -n $api_url ]] || return 1
    is_wakatime_cloud "$api_url" && return 1
    is_true "$sync_ai_disabled" && return 1
    [[ -n $api_key || -n $api_key_vault_cmd || -n ${WAKATIME_API_KEY:-} ]] || return 1
    return 0
}

find_cli() {
    local candidate
    if [[ -n ${WAKATIME_CLI:-} && -x ${WAKATIME_CLI} ]]; then
        printf '%s' "$WAKATIME_CLI"
        return 0
    fi
    if candidate="$(command -v wakatime-cli 2>/dev/null)" && [[ -n $candidate ]]; then
        printf '%s' "$candidate"
        return 0
    fi
    candidate="$(state_dir)/wakatime-cli"
    if [[ -x $candidate ]]; then
        printf '%s' "$candidate"
        return 0
    fi
    return 1
}

debug_enabled() {
    is_true "$debug_setting"
}

log() {
    debug_enabled || return 0
    local dir file
    dir="$(state_dir)"
    mkdir -p "$dir" || return 0
    file="${dir}/wakatime.log"
    printf '%s lrstanley-skills wakapi hook: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >> "$file"
}

recently_synced() {
    local stamp now last interval
    stamp="$(stamp_file)"
    [[ -f $stamp ]] || return 1
    now="$(date +%s)"
    last="$(tr -cd '0-9' < "$stamp" || true)"
    [[ -n $last ]] || return 1
    interval="$(sync_interval)"
    if (( now - last < interval )); then
        return 0
    fi
    return 1
}

acquire_lock() {
    local dir lock lockdir now mtime
    dir="$(state_dir)"
    mkdir -p "$dir" || return 1

    if command -v flock >/dev/null 2>&1; then
        lock="${dir}/lrstanley-skills-ai.lock"
        exec 9>>"$lock" || return 1
        flock -n 9 || return 1
        return 0
    fi

    lockdir="${dir}/lrstanley-skills-ai.lockdir"
    if mkdir "$lockdir" 2>/dev/null; then
        return 0
    fi
    now="$(date +%s)"
    mtime="$(stat -c %Y "$lockdir" 2>/dev/null || stat -f %m "$lockdir" 2>/dev/null || printf '0')"
    if (( now - mtime > 180 )); then
        rmdir "$lockdir" 2>/dev/null || return 1
        mkdir "$lockdir" 2>/dev/null || return 1
        return 0
    fi
    return 1
}

release_lock() {
    local lockdir
    command -v flock >/dev/null 2>&1 && return 0
    lockdir="$(state_dir)/lrstanley-skills-ai.lockdir"
    rmdir "$lockdir" 2>/dev/null || true
}

plugin_arg() {
    local editor version
    editor="$(printf '%s' "$1" | tr -cd 'A-Za-z0-9._-')"
    version="unknown"
    case "$editor" in
        cursor) version="${CURSOR_VERSION:-unknown}" ;;
        claude-code) version="${CLAUDE_VERSION:-unknown}" ;;
    esac
    version="$(printf '%s' "$version" | tr -cd 'A-Za-z0-9._-')"
    [[ -n $version ]] || version="unknown"
    case "$editor" in
        cursor) printf 'Cursor/%s %s/wakapi' "$version" "$plugin_name" ;;
        claude-code) printf 'ClaudeCode/%s %s/wakapi' "$version" "$plugin_name" ;;
        *) printf '%s/wakapi' "$plugin_name" ;;
    esac
}

project_dir() {
    if [[ -n ${CURSOR_PROJECT_DIR:-} && -d ${CURSOR_PROJECT_DIR} ]]; then
        printf '%s' "$CURSOR_PROJECT_DIR"
        return
    fi
    if [[ -n ${CLAUDE_PROJECT_DIR:-} && -d ${CLAUDE_PROJECT_DIR} ]]; then
        printf '%s' "$CLAUDE_PROJECT_DIR"
        return
    fi
}

run_cli() {
    local cli="$1"
    local editor="$2"
    local project="$3"
    local -a args
    args=(--sync-ai-activity --plugin "$(plugin_arg "$editor")")
    if [[ -n $project && $project != -* && -d $project ]]; then
        args+=(--project-folder "$project")
    fi

    log "syncing ai activity"
    if command -v timeout >/dev/null 2>&1; then
        timeout 90 "$cli" "${args[@]}" >/dev/null 2>&1 || return 1
        return 0
    fi
    "$cli" "${args[@]}" >/dev/null 2>&1 || return 1
}

run_sync() {
    local editor="${1:-}"
    local project="${2:-}"
    local cli

    configured || return 0
    cli="$(find_cli)" || {
        log "wakatime-cli not found"
        return 0
    }
    acquire_lock || return 0
    trap release_lock EXIT
    if recently_synced; then
        return 0
    fi
    printf '%s\n' "$(date +%s)" > "$(stamp_file)" || return 0
    if ! run_cli "$cli" "$editor" "$project"; then
        log "sync failed"
    fi
}

spawn_sync() {
    local editor="$1"
    local project="$2"
    local self
    self="$(readlink -f -- "$0" 2>/dev/null || printf '%s' "$0")"
    if command -v setsid >/dev/null 2>&1; then
        setsid "$self" --sync "$editor" "$project" </dev/null >/dev/null 2>&1 &
    else
        nohup "$self" --sync "$editor" "$project" </dev/null >/dev/null 2>&1 &
    fi
    disown >/dev/null 2>&1 || true
}

detect_editor() {
    if [[ -n ${CURSOR_VERSION:-} || -n ${CURSOR_PLUGIN_ROOT:-} ]]; then
        printf '%s' "cursor"
        return
    fi
    if [[ -n ${CLAUDE_PLUGIN_ROOT:-} ]]; then
        printf '%s' "claude-code"
        return
    fi
}

hook_main() {
    local editor="${1:-}"
    local project

    if [[ -t 0 ]]; then
        :
    else
        cat >/dev/null || true
    fi

    [[ -n $editor ]] || editor="$(detect_editor)"
    project="$(project_dir || true)"

    configured || return 0
    find_cli >/dev/null || return 0
    recently_synced && return 0

    if [[ ${WAKAPI_HOOK_FOREGROUND:-} == 1 ]]; then
        run_sync "$editor" "$project"
        return 0
    fi
    spawn_sync "$editor" "$project"
}

main() {
    if [[ ${1:-} == "--sync" ]]; then
        shift
        run_sync "$@"
        return 0
    fi
    hook_main "$@"
}

main "$@"
