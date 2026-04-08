#!/bin/bash

# OpenClaw Session Audit Script
# Analyzes session logs and outputs a summary report

SESSIONS_DIR="/Users/keenaben/.openclaw/agents/main/sessions"
REPORT_TIMESTAMP=$(date '+%Y-%m-%d %H:%M')
SEVEN_DAYS_AGO=$(date -v-7d '+%Y-%m-%d' 2>/dev/null || date -d '7 days ago' '+%Y-%m-%d')

echo "🔍 Session Audit Report - $REPORT_TIMESTAMP"
echo "Agent: ripley | Model: gemma-4-e2b-it"
echo "=========================================="
echo ""

# Total sessions
TOTAL=$(ls "$SESSIONS_DIR"/*.jsonl 2>/dev/null | grep -v '.reset.' | grep -v '.lock' | wc -l | tr -d ' ')
echo "Total Sessions: $TOTAL"

# Recent sessions, messages, tokens
RECENT_SESSIONS=0
RECENT_MESSAGES=0
RECENT_INPUT=0
RECENT_OUTPUT=0
RECENT_CACHE_READ=0
RECENT_CACHE_WRITE=0

for f in "$SESSIONS_DIR"/*.jsonl; do
    [[ "$f" == *".reset."* ]] && continue
    [[ "$f" == *".lock"* ]] && continue
    
    session_date=$(head -1 "$f" | jq -r '.timestamp' 2>/dev/null | cut -dT -f1)
    
    if [[ "$session_date" > "$SEVEN_DAYS_AGO" ]] || [[ "$session_date" == "$SEVEN_DAYS_AGO" ]]; then
        ((RECENT_SESSIONS++))
        msg_count=$(jq -s 'map(select(.type == "message")) | length' "$f" 2>/dev/null || echo "0")
        RECENT_MESSAGES=$((RECENT_MESSAGES + msg_count))
        
        # Sum tokens - use .message.usage.input (not inputTokens)
        input=$(jq -s '[.[] | select(.message.usage.input) | .message.usage.input] | add' "$f" 2>/dev/null || echo "0")
        output=$(jq -s '[.[] | select(.message.usage.output) | .message.usage.output] | add' "$f" 2>/dev/null || echo "0")
        cache_r=$(jq -s '[.[] | select(.message.usage.cacheRead) | .message.usage.cacheRead] | add' "$f" 2>/dev/null || echo "0")
        cache_w=$(jq -s '[.[] | select(.message.usage.cacheWrite) | .message.usage.cacheWrite] | add' "$f" 2>/dev/null || echo "0")
        
        RECENT_INPUT=$(python3 -c "print($RECENT_INPUT + $input)" 2>/dev/null)
        RECENT_OUTPUT=$(python3 -c "print($RECENT_OUTPUT + $output)" 2>/dev/null)
        RECENT_CACHE_READ=$(python3 -c "print($RECENT_CACHE_READ + $cache_r)" 2>/dev/null)
        RECENT_CACHE_WRITE=$(python3 -c "print($RECENT_CACHE_WRITE + $cache_w)" 2>/dev/null)
    fi
done

echo "Recent Sessions (7 days): $RECENT_SESSIONS"
echo "Recent Messages (7 days): $RECENT_MESSAGES"
echo "Recent Input Tokens (7 days): $RECENT_INPUT"
echo "Recent Output Tokens (7 days): $RECENT_OUTPUT"
echo "Recent Cache Read (7 days): $RECENT_CACHE_READ"
echo "Recent Cache Write (7 days): $RECENT_CACHE_WRITE"

echo ""
echo "=========================================="

# Total storage
TOTAL_SIZE=$(du -sh "$SESSIONS_DIR" 2>/dev/null | cut -f1)
echo "Total Session Storage: $TOTAL_SIZE"

# Top 5 largest sessions
echo ""
echo "📊 Largest Sessions:"
for f in $(ls -S "$SESSIONS_DIR"/*.jsonl 2>/dev/null | grep -v '.reset.' | grep -v '.lock' | head -5); do
    size=$(du -h "$f" | cut -f1)
    sid=$(basename "$f" .jsonl)
    date=$(head -1 "$f" | jq -r '.timestamp' 2>/dev/null | cut -dT -f1)
    echo "  $date  $size  $sid"
done

echo ""
echo "✅ Session audit complete"
