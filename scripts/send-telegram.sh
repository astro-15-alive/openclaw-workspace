#!/bin/bash
# send-telegram.sh - Send message via Telegram Bot API
# Usage: send-telegram.sh <message>

set -a
source ~/.openclaw/.env 2>/dev/null
set +a

MESSAGE="${1:-}"

if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_CHAT_ID" ]; then
    echo "Error: TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID not set"
    exit 1
fi

if [ -z "$MESSAGE" ]; then
    echo "Usage: send-telegram.sh <message>"
    exit 1
fi

curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
    -d "chat_id=$TELEGRAM_CHAT_ID" \
    -d "text=$MESSAGE" \
    -d "parse_mode=Markdown" > /dev/null

if [ $? -eq 0 ]; then
    echo "Message sent successfully"
    exit 0
else
    echo "Failed to send message"
    exit 1
fi
