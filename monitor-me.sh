#!/bin/bash

if [[ -f .env ]]; then
    source .env
else
    echo "Where is .env?"
    exit 1
fi

# Percentage thresholds
cpu_threshold=70
ram_threshold=70
disk_threshold=30

# Get metrics
cpu_usage=$(top -b -n 1 | grep "Cpu(s)" | awk '{print $2}')
ram_usage=$(free | grep Mem | awk '{print ($3 / $2) * 100}')
disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')

# Get public IP address
public_ip="🌐 IP: $(curl -4 ifconfig.me)"

send_telegram_message() {
    local message="$1"
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d "chat_id=$CHAT_ID" \
        -d "text=$message"
}

message=""
if (( $(echo "$cpu_usage > $cpu_threshold" | bc -l) )); then
    message+="
🚨 CPU usage: $cpu_usage%
$public_ip"
fi

if (( $(echo "$ram_usage > $ram_threshold" | bc -l) )); then
    message+="
🚨 RAM usage: $ram_usage%
$public_ip
"
fi

if (( $(echo "$disk_usage > $disk_threshold" | bc -l) )); then
    message+="
🚨 Disk space below $disk_usage%
$public_ip
"
fi

# Check if at least one condition is met before sending a message
if [ -n "$message" ]; then
    send_telegram_message "$message"
fi
