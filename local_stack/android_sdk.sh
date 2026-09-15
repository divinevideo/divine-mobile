#!/usr/bin/env bash
# android_sdk.sh — ensure Android SDK binaries (adb, emulator) are on PATH.
#
# Source this from any local_stack script that shells out to adb or emulator.
# Scripts invoked outside an interactive shell (ouija-spawned tmux panes, CI
# runners, mise subprocesses) do not source ~/.zshrc or ~/.bashrc, so any
# PATH amendments the developer keeps there are missing. This searches the
# standard Android SDK locations and exports PATH + ANDROID_HOME idempotently.

if ! command -v emulator >/dev/null 2>&1 || ! command -v adb >/dev/null 2>&1; then
    for _candidate in "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}" \
                      "$HOME/Android/Sdk" "$HOME/Library/Android/sdk"; do
        if [[ -n "$_candidate" && -d "$_candidate/platform-tools" ]]; then
            export ANDROID_HOME="$_candidate"
            export PATH="$_candidate/emulator:$_candidate/platform-tools:$PATH"
            break
        fi
    done
    unset _candidate
fi

x11_socket_dir() {
    printf '%s\n' "${X11_SOCKET_DIR:-/tmp/.X11-unix}"
}

x11_display_number() {
    local display="${1:-}"
    display="${display#*:}"
    display="${display%%.*}"
    printf '%s\n' "$display"
}

x11_socket_path() {
    local display_number
    display_number="$(x11_display_number "${1:-}")"
    if [[ -z "$display_number" ]]; then
        return 1
    fi
    printf '%s/X%s\n' "$(x11_socket_dir)" "$display_number"
}

detect_x11_display() {
    local candidate="${DISPLAY:-}"
    local display_number
    local socket_path

    if [[ -n "$candidate" ]]; then
        display_number="$(x11_display_number "$candidate")"
        socket_path="$(x11_socket_path "$candidate")"
        if [[ -S "$socket_path" ]]; then
            printf ':%s\n' "$display_number"
            return
        fi
    fi

    for socket_path in "$(x11_socket_dir)"/X*; do
        if [[ -S "$socket_path" ]]; then
            printf ':%s\n' "${socket_path##*/X}"
            return
        fi
    done

    printf '\n'
}

first_available_avd_name() {
    emulator -list-avds 2>/dev/null | sed -n '1p'
}

local_stack_has_running_container() {
    local compose_file="$1"
    local container_ids

    if ! container_ids="$(docker compose -f "$compose_file" ps --status running -q 2>/dev/null)"; then
        return 1
    fi

    [[ -n "$container_ids" ]]
}
