#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

ENV_PATH="${ENV_PATH:-/opt/monitor-me/.env}"

log_err() {
    echo "[$(basename "$0")] $*" >&2
}

require_command() {
    local cmd="$1"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log_err "Missing required command: $cmd"
        exit 1
    fi
}

if [[ -f "$ENV_PATH" ]]; then
    # shellcheck source=/dev/null
    source "$ENV_PATH"
else
    log_err "Where is $ENV_PATH?"
    exit 1
fi

BOT_TOKEN="${BOT_TOKEN:-${TOKEN:-}}"
CHAT_ID="${CHAT_ID:-}"

if [[ -z "$BOT_TOKEN" || -z "$CHAT_ID" ]]; then
    log_err "BOT_TOKEN/TOKEN and CHAT_ID must be set in $ENV_PATH"
    exit 1
fi

for cmd in awk curl free df ps find sort head; do
    require_command "$cmd"
done

# Percentage thresholds (can be overridden in .env)
cpu_threshold="${CPU_THRESHOLD:-10}"
ram_threshold="${RAM_THRESHOLD:-10}"
disk_threshold="${DISK_THRESHOLD:-10}"

TELEGRAM_TIMEOUT="${TELEGRAM_TIMEOUT:-8}"
MAX_MESSAGE_LENGTH="${MAX_MESSAGE_LENGTH:-3500}"
LARGEST_FILES_LIMIT="${LARGEST_FILES_LIMIT:-5}"
DISK_SCAN_PATHS="${DISK_SCAN_PATHS:-/var /home /opt}"

get_public_ip() {
    local ip

    if command -v ip >/dev/null 2>&1; then
        # Resolve source address from local routing table (no external HTTP call).
        ip="$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i=1; i<=NF; i++) if ($i=="src") {print $(i+1); exit}}')"
        if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
            echo "$ip"
            return
        fi

        # Fallback: first global IPv4 address on an active interface.
        ip="$(ip -o -4 addr show scope global up 2>/dev/null | awk '{split($4, a, "/"); print a[1]; exit}')"
        if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
            echo "$ip"
            return
        fi
    fi

    echo "unknown"
}

get_cpu_usage() {
    local user nice system idle iowait irq softirq steal
    local total_1 total_2 idle_1 idle_2 total_diff idle_diff

    read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
    total_1=$((user + nice + system + idle + iowait + irq + softirq + steal))
    idle_1=$((idle + iowait))

    sleep 0.5

    read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
    total_2=$((user + nice + system + idle + iowait + irq + softirq + steal))
    idle_2=$((idle + iowait))

    total_diff=$((total_2 - total_1))
    idle_diff=$((idle_2 - idle_1))

    if (( total_diff <= 0 )); then
        echo "0.0"
        return
    fi

    awk -v td="$total_diff" -v id="$idle_diff" 'BEGIN { printf "%.1f", ((td - id) * 100) / td }'
}

is_above_threshold() {
    local value="$1"
    local threshold="$2"
    awk -v v="$value" -v t="$threshold" 'BEGIN { exit !(v > t) }'
}

collect_largest_files() {
    local -a scan_paths=()
    local -a existing_paths=()
    local normalized_paths
    local path

    normalized_paths="$(printf '%s' "$DISK_SCAN_PATHS" | tr ',' ' ')"
    local IFS=$' \t\n'
    read -r -a scan_paths <<< "$normalized_paths"
    for path in "${scan_paths[@]}"; do
        if [[ -d "$path" ]]; then
            existing_paths+=("$path")
        fi
    done

    if ((${#existing_paths[@]} == 0)); then
        echo "No valid scan paths configured."
        return
    fi

    find "${existing_paths[@]}" -xdev -type f -exec du -h {} + 2>/dev/null \
        | sort -rh \
        | head -n "$LARGEST_FILES_LIMIT"
}

send_telegram_message() {
    local message="$1"
    curl -fsS --max-time "$TELEGRAM_TIMEOUT" --retry 2 --retry-delay 1 \
        -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=${CHAT_ID}" \
        --data-urlencode "text=${message}" >/dev/null
}

public_ip="$(get_public_ip)"
cpu_usage="$(get_cpu_usage)"
ram_usage="$(free | awk '/^Mem:/ { printf "%.1f", ($3 / $2) * 100 }')"
disk_usage="$(df -P / | awk 'NR==2 { gsub(/%/, "", $5); print $5 + 0 }')"

top_cpu_process="$(ps -eo pid,comm,%cpu --sort=-%cpu | head -n 4)"
top_memory_process="$(ps -eo pid,comm,%mem --sort=-%mem | head -n 4)"

message=""

if is_above_threshold "$cpu_usage" "$cpu_threshold"; then
    message+=$'🚨 CPU usage above threshold\n'
    message+="🌐 IP: ${public_ip}"$'\n'
    message+="⚙️ CPU usage: ${cpu_usage}%"$'\n'
    message+="${top_cpu_process}"$'\n\n'
fi

if is_above_threshold "$ram_usage" "$ram_threshold"; then
    message+=$'🚨 RAM usage above threshold\n'
    message+="🌐 IP: ${public_ip}"$'\n'
    message+="⚙️ RAM usage: ${ram_usage}%"$'\n'
    message+="${top_memory_process}"$'\n\n'
fi

if is_above_threshold "$disk_usage" "$disk_threshold"; then
    largest_files="$(collect_largest_files || true)"
    message+=$'🚨 Disk usage above threshold\n'
    message+="🌐 IP: ${public_ip}"$'\n'
    message+="💾 Disk usage: ${disk_usage}%"$'\n'
    message+=$'📂 Largest files:\n'
    message+="${largest_files:-n/a}"$'\n\n'
fi

if [[ -n "$message" ]]; then
    if (( ${#message} > MAX_MESSAGE_LENGTH )); then
        message="${message:0:MAX_MESSAGE_LENGTH}"$'\n...[truncated]'
    fi
    send_telegram_message "$message"
fi
