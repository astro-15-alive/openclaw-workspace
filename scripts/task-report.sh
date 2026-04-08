#!/bin/bash
# Task Report Script
# Outputs Discord-formatted task status

source ~/.openclaw/secrets.env 2>/dev/null

echo "📋 **Daily Task Report** - $(date '+%A, %B %d, %Y')"
echo ""
echo "**Open Tasks:**"
OUTPUT=$(~/.openclaw/workspace/scripts/tasks.sh list 2>/dev/null)
if [ -z "$OUTPUT" ] || [ "$OUTPUT" = "=== Astro Tasks ===" ]; then
    echo "• None"
else
    echo "$OUTPUT" | while read line; do
        echo "• $line"
    done
fi

echo ""
echo "**Completed Tasks:**"
COMPLETED=$(~/.openclaw/workspace/scripts/tasks.sh completed 2>/dev/null)
if [ -z "$COMPLETED" ] || [ "$COMPLETED" = "=== Completed Tasks ===" ]; then
    echo "• None"
else
    echo "$COMPLETED" | grep -v "=== Completed Tasks ===" | grep -v "^$" | while IFS=$'\t' read -r id list priority status date title; do
        TITLE=$(echo "$title" | cut -c1-80)
        echo "• $TITLE"
    done
fi
