#!/bin/bash
# check-upcoming-events.sh - Check for calendar events starting in 30 minutes and send Telegram alerts
# Only alerts once per event (tracks alerted events to avoid duplicates)

STATE_FILE="$HOME/.openclaw/workspace/.calendar-alerts-state"
ALERT_WINDOW_MINUTES=30

# Create state file if it doesn't exist
touch "$STATE_FILE"

# Get current timestamp
CURRENT_TIME=$(date +%s)

# Get events starting in the next 30 minutes
# Format: eventTitle (tab) startDate
EVENTS=$(icalBuddy -po eventTitle,startDate,location -n 20 -b "" eventsFrom:now to:now+$ALERT_WINDOW_MINUTES 2>/dev/null | grep -v "No events")

if [ -z "$EVENTS" ] || [ "$EVENTS" = "" ]; then
    exit 0
fi

# Process each event
ALERT_COUNT=0
MESSAGE="📅 **Upcoming Event(s)** (30 min reminder)

"

while IFS= read -r line; do
    # Parse event title and start time from icalBuddy output
    if [[ "$line" == *$'\t'* ]]; then
        EVENT_TITLE=$(echo "$line" | cut -f1)
        EVENT_TIME=$(echo "$line" | cut -f2)
        EVENT_LOCATION=$(echo "$line" | cut -f3)
        
        # Create unique identifier for this event (title + time)
        EVENT_ID=$(echo "$EVENT_TITLE|$EVENT_TIME" | md5)
        
        # Check if we already alerted for this event
        if ! grep -q "$EVENT_ID" "$STATE_FILE" 2>/dev/null; then
            # New event - add to alert message
            ALERT_COUNT=$((ALERT_COUNT + 1))
            MESSAGE+="• **$EVENT_TITLE**
  🕐 $EVENT_TIME"
            
            if [ -n "$EVENT_LOCATION" ]; then
                MESSAGE+="
  📍 $EVENT_LOCATION"
            fi
            
            MESSAGE+="

"
            
            # Mark as alerted (with timestamp for cleanup)
            echo "$EVENT_ID|$CURRENT_TIME" >> "$STATE_FILE"
        fi
    fi
done <<< "$EVENTS"

# Send Telegram alert if there are new events
if [ $ALERT_COUNT -gt 0 ]; then
    ~/.openclaw/workspace/scripts/send-telegram.sh "$MESSAGE"
fi

# Cleanup: Remove alerts older than 2 hours (7200 seconds) to keep file small
if [ -f "$STATE_FILE" ]; then
    CUTOFF_TIME=$((CURRENT_TIME - 7200))
    grep -E "\|[0-9]+$" "$STATE_FILE" 2>/dev/null | while IFS='|' read -r id timestamp; do
        if [ "$timestamp" -lt "$CUTOFF_TIME" ] 2>/dev/null; then
            grep -v "^$id|" "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
        fi
    done
fi