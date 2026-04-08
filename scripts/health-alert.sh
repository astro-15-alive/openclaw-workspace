#!/bin/bash
# Health check + alert via local gemma model
# Only sends Telegram if issues found

source ~/.openclaw/secrets.env 2>/dev/null

RESULT=$(~/.openclaw/workspace/scripts/health-check.sh)

# OK = nothing to do
if [ "$RESULT" = "OK" ]; then
    exit 0
fi

# Issues or warnings found — format with gemma and send Telegram
PROMPT="A health check just ran on Ben's Mac mini (OpenClaw assistant: Astro). Something needs attention. Format a short, casual Telegram alert (max 3-4 sentences, under 300 chars total) that:
1. Names what is wrong/behaving oddly
2. Is conversational, not robotic
3. Includes a very brief suggested fix or note

Health check result: ${RESULT}

Output ONLY the formatted message, nothing else."

RESPONSE=$(curl -s -X POST "http://localhost:1234/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d "{\"model\": \"gemma-4-e2b-it\", \"messages\": [{\"role\": \"user\", \"content\": \"${PROMPT}\"}], \"max_tokens\": 100, \"temperature\": 0.7}" \
    2>/dev/null)

MESSAGE=$(echo "$RESPONSE" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['choices'][0]['message']['content'])" 2>/dev/null)

if [ -z "$MESSAGE" ]; then
    MESSAGE="$RESULT"
fi

~/.openclaw/workspace/scripts/send-telegram.sh "$MESSAGE"
