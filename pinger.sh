#!/bin/bash

if [[ -f .env ]]; then
    source .env
else
    echo "Where is .env?"
    exit 1
fi

for HOST in "${HOSTS[@]}"; do
    if ! ping -c 1 $HOST &> /dev/null; then
        MESSAGE="❌ $HOST is down"
        curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d "chat_id=$CHAT_ID&text=$MESSAGE"
    fi
done
