#!/bin/bash
# tasks.sh - Astro task management
# Usage: tasks.sh {list|add|add-note|complete} [args]

# Auto-source environment variables
set -a
source ~/.openclaw/.env 2>/dev/null
set +a

COMMAND="${1:-}"
shift || true

case "$COMMAND" in
    list)
        # Check for --list flag
        if [[ "$1" == "--list" && "$2" == "completed" ]]; then
            echo "=== Completed Tasks ==="
            # Only show tasks where isCompleted is false (open status)
            remindctl list completed --json 2>&1 | python3 -c "
import sys, json
data = json.load(sys.stdin)
for task in data:
    if not task.get('isCompleted', False):
        print(f\"{task['id']}\t{task['listName']}\t0\tnone\t{task['title']}\")
"
        else
            echo "=== Astro Tasks ==="
            remindctl list astro --plain 2>&1
        fi
        ;;
    completed)
        echo "=== Completed Tasks ==="
        remindctl list completed --plain 2>&1
        ;;
    add)
        TASK_TITLE="$*"
        if [ -z "$TASK_TITLE" ]; then
            echo "Usage: tasks.sh add <task description>"
            exit 1
        fi
        remindctl add -l astro "$TASK_TITLE" 2>&1
        ;;
    add-note)
        TASK_ID="${1:-}"
        NOTE="${2:-}"
        if [ -z "$TASK_ID" ] || [ -z "$NOTE" ]; then
            echo "Usage: tasks.sh add-note <id> <note>"
            exit 1
        fi
        remindctl edit "$TASK_ID" --notes "$NOTE" 2>&1
        ;;
    complete)
        TASK_ID="${1:-}"
        if [ -z "$TASK_ID" ]; then
            echo "Usage: tasks.sh complete <id>"
            exit 1
        fi
        remindctl edit "$TASK_ID" --list completed 2>&1
        ;;
    help)
        echo "Usage: tasks.sh {list|add|add-note|complete} [args]"
        echo ""
        echo "Commands:"
        echo "  list                    Show open astro tasks"
        echo "  add <description>       Add new task to astro queue"
        echo "  completed               Show completed tasks"
        echo "  add-note <id> <note>    Add notes to task"
        echo "  complete <id>           Move task to completed list"
        ;;
    *)
        echo "Usage: tasks.sh {list|add|add-note|complete} [args]"
        echo "Run 'tasks.sh help' for more info."
        ;;
esac
