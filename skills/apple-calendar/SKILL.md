---
name: apple-calendar
description: Create and manage Apple Calendar events via AppleScript. Use when the user wants to add events to their Apple Calendar, schedule meetings, or create calendar entries with specific dates and times. Works with macOS Calendar app.
---

# Apple Calendar

Create calendar events on macOS using Apple Calendar (formerly iCal).

## When to Use

Use this skill when the user wants to:
- Add a new event to their Apple Calendar
- Schedule a meeting or appointment
- Create a calendar entry with specific date/time
- Block out time on their calendar

## How to Use

### Creating an Event

Use the provided script to create calendar events:

```bash
~/.openclaw/workspace/skills/apple-calendar/scripts/add-calendar-event.sh "<title>" "<start_date>" "<end_date>" [calendar_name]
```

**Parameters:**
- `title`: Event title (required)
- `start_date`: Start date/time in system locale format (required)
- `end_date`: End date/time in system locale format (required)
- `calendar_name`: Calendar to add to (optional, defaults to "Calendar")

**Date Format:**

The date format depends on your macOS system locale settings. Common formats:

- **Australian format:** `"4 April 2026 at 12:00:00"` (24-hour time)
- **US format:** `"Saturday, April 4, 2026 at 12:00:00 PM"`

**Examples:**

Create a 3-hour event today at noon:
```bash
~/.openclaw/workspace/skills/apple-calendar/scripts/add-calendar-event.sh "Install attic boards" "4 April 2026 at 12:00:00" "4 April 2026 at 15:00:00"
```

Create an event in a specific calendar:
```bash
~/.openclaw/workspace/skills/apple-calendar/scripts/add-calendar-event.sh "Team Meeting" "4 April 2026 at 14:00:00" "4 April 2026 at 15:00:00" "business"
```

## Available Calendars

To see available calendars:
```bash
osascript -e 'tell application "Calendar" to get name of calendars'
```

Common calendars:
- `Calendar` (default)
- `Scheduled Reminders`
- `Birthdays`
- `Australian Holidays`
- `Siri Suggestions`

## Important Notes

- The script uses AppleScript to interact with the Calendar app
- Date format must match your macOS system locale
- Requires Calendar app to be installed (standard on macOS)
- Events are created immediately without opening Calendar app
- The script returns confirmation with the created event details