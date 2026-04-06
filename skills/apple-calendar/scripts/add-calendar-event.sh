#!/bin/bash
# add-calendar-event.sh - Add event to Apple Calendar
# Usage: add-calendar-event.sh "<title>" <start_date> <end_date> [calendar_name]

TITLE="$1"
START_DATE="$2"
END_DATE="$3"
CALENDAR_NAME="${4:-Calendar}"

if [ -z "$TITLE" ] || [ -z "$START_DATE" ] || [ -z "$END_DATE" ]; then
    echo "Usage: $0 \"<title>\" \"<start_date>\" \"<end_date>\" [calendar_name]"
    echo "Date format (for your system): \"Saturday, 4 April 2026 at 12:00:00 pm\""
    exit 1
fi

osascript <<APPLESCRIPT
tell application "Calendar"
    tell calendar "$CALENDAR_NAME"
        set startDate to date "$START_DATE"
        set endDate to date "$END_DATE"
        set newEvent to make new event with properties {summary:"$TITLE", start date:startDate, end date:endDate}
        return "Created event: " & (summary of newEvent) & " from " & (start date of newEvent) & " to " & (end date of newEvent)
    end tell
end tell
APPLESCRIPT