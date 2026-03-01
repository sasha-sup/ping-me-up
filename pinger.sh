#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="${0##*/}"
DEFAULT_ENV_PATH="${SCRIPT_DIR}/.env"
LEGACY_ENV_PATH="/home/sasha/Code/ping-me-up/.env"
ENV_PATH="${ENV_PATH:-$DEFAULT_ENV_PATH}"

PORT="${PORT:-22}"
CONNECT_TIMEOUT="${CONNECT_TIMEOUT:-2}"
TELEGRAM_TIMEOUT="${TELEGRAM_TIMEOUT:-8}"

log_err() {
    echo "[$SCRIPT_NAME] $*" >&2
}

require_command() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log_err "Missing required command: $cmd"
        exit 1
    fi
}

is_positive_int() {
    [[ "${1:-}" =~ ^[1-9][0-9]*$ ]]
}

load_env() {
    if [[ -f "$ENV_PATH" ]]; then
        # shellcheck source=/dev/null
        source "$ENV_PATH"
        return
    fi

    # Compatibility fallback for old hardcoded path.
    if [[ -f "$LEGACY_ENV_PATH" ]]; then
        ENV_PATH="$LEGACY_ENV_PATH"
        # shellcheck source=/dev/null
        source "$ENV_PATH"
        return
    fi

    log_err "Where is $ENV_PATH?"
    exit 1
}

send_telegram_message() {
    local message="$1"
    curl -fsS --max-time "$TELEGRAM_TIMEOUT" --retry 2 --retry-delay 1 \
        -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=${CHAT_ID}" \
        --data-urlencode "text=${message}" >/dev/null
}

main() {
    local host name ip message

    require_command nc
    require_command curl
    load_env

    BOT_TOKEN="${BOT_TOKEN:-${TOKEN:-}}"
    CHAT_ID="${CHAT_ID:-}"

    if ! is_positive_int "$PORT"; then
        log_err "PORT must be a positive integer"
        exit 1
    fi

    if ! is_positive_int "$CONNECT_TIMEOUT"; then
        log_err "CONNECT_TIMEOUT must be a positive integer"
        exit 1
    fi

    if ! is_positive_int "$TELEGRAM_TIMEOUT"; then
        log_err "TELEGRAM_TIMEOUT must be a positive integer"
        exit 1
    fi

    if [[ -z "$BOT_TOKEN" || -z "$CHAT_ID" ]]; then
        log_err "BOT_TOKEN/TOKEN and CHAT_ID must be set in $ENV_PATH"
        exit 1
    fi

    if [[ -z "${HOSTS+x}" ]] || ((${#HOSTS[@]} == 0)); then
        log_err "HOSTS array is empty in $ENV_PATH"
        exit 1
    fi

    for host in "${HOSTS[@]}"; do
        IFS=' ' read -r name ip <<< "$host"
        if [[ -z "${name:-}" || -z "${ip:-}" ]]; then
            log_err "Skip invalid HOSTS entry: $host"
            continue
        fi

        if nc -z -w "$CONNECT_TIMEOUT" "$ip" "$PORT" >/dev/null 2>&1; then
            message="✅ $name ($ip) is reachable on port $PORT"
            printf '%s\n' "$message"
            continue
        fi

        message="❌ $name ($ip) is down on port $PORT"
        send_telegram_message "$message" || log_err "Failed to notify for $name ($ip)"
    done
}

main "$@"
