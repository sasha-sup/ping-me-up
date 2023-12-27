#!/bin/bash

ENV_FILE="/home/sasha/Code/ping-me-up/.env"
PORT=22

if [[ -f "$ENV_FILE" ]]; then
    source "$ENV_FILE"
else
    echo "Where is $ENV_FILE?"
    exit 1
fi

for HOST in "${HOSTS[@]}"; do
    IFS=" " read -r NAME IP <<< "$HOST"

    if nc -zv -w 2 "$IP" "$PORT" &> /dev/null; then
        MESSAGE="✅ $NAME ($IP) is reachable on port $PORT"
        echo $MESSAGE
        # curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d "chat_id=$CHAT_ID&text=$MESSAGE"
    else
        MESSAGE="❌ $NAME ($IP) is down on port $PORT"
        curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" -d "chat_id=$CHAT_ID&text=$MESSAGE"
    fi
done
