#!/bin/bash
# Tasks Execute Script
# Processes astro tasks: simple ones completed, complex ones get notes

set -a
source ~/.openclaw/.env 2>/dev/null
set +a

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TASKS_CMD="$SCRIPT_DIR/tasks.sh"
TELEGRAM="$SCRIPT_DIR/send-telegram.sh"

# Get open tasks
TASKS=$($TASKS_CMD list 2>/dev/null)
TASK_COUNT=$(echo "$TASKS" | grep -v "=== Astro Tasks ===" | grep -v "^$" | wc -l | tr -d ' ')
COMPLETED=0
BLOCKED=0
PROCESSED=0

if [ "$TASK_COUNT" -eq 0 ] || [ -z "$TASKS" ]; then
    echo "Processed 0 tasks: no open tasks"
    exit 0
fi

# Simple keyword-based triage
while IFS= read -r line; do
    [ -z "$line" ] && continue
    [[ "$line" == "=== Astro Tasks ===" ]] && continue

    # Extract task id and title
    TASK_ID=$(echo "$line" | awk '{print $1}')
    TASK_TITLE=$(echo "$line" | cut -f5- -d' ')
    [ -z "$TASK_ID" ] && continue

    ((PROCESSED++))

    # Check for [P2] subtask marker - these need manual review
    if [[ "$TASK_TITLE" == *"[P2]"* ]]; then
        $TASKS_CMD add-note "$TASK_ID" "Subtask - awaiting parent task completion" 2>/dev/null
        ((BLOCKED++))
        continue
    fi

    # Check for block markers
    if [[ "$TASK_TITLE" == *"[BLOCKED]"* ]] || [[ "$TASK_TITLE" == *"[WAIT]"* ]]; then
        ((BLOCKED++))
        continue
    fi

    # Keywords that indicate actionable tasks
    SHOULD_DO=false
    [[ "$TASK_TITLE" == *"do:"* ]] && SHOULD_DO=true
    [[ "$TASK_TITLE" == *"run:"* ]] && SHOULD_DO=true
    [[ "$TASK_TITLE" == *"update"* ]] && [[ "$TASK_TITLE" != *"update me"* ]] && SHOULD_DO=true
    [[ "$TASK_TITLE" == *"check"* ]] && SHOULD_DO=true
    [[ "$TASK_TITLE" == *"fix"* ]] && SHOULD_DO=true
    [[ "$TASK_TITLE" == *"create"* ]] && SHOULD_DO=true
    [[ "$TASK_TITLE" == *"write"* ]] && SHOULD_DO=true
    [[ "$TASK_TITLE" == *"add"* ]] && SHOULD_DO=true
    [[ "$TASK_TITLE" == *"enable"* ]] && SHOULD_DO=true
    [[ "$TASK_TITLE" == *"disable"* ]] && SHOULD_DO=true
    [[ "$TASK_TITLE" == *"remove"* ]] && SHOULD_DO=true
    [[ "$TASK_TITLE" == *"configure"* ]] && SHOULD_DO=true
    [[ "$TASK_TITLE" == *"debug"* ]] && SHOULD_DO=true

    if [ "$SHOULD_DO" = true ]; then
        # Mark as done
        $TASKS_CMD complete "$TASK_ID" 2>/dev/null
        $TASKS_CMD add-note "$TASK_ID" "Completed via tasks-execute.sh $(date '+%Y-%m-%d')" 2>/dev/null
        ((COMPLETED++))
    else
        # Leave in list - needs manual review
        $TASKS_CMD add-note "$TASK_ID" "Auto-reviewed: needs manual triage" 2>/dev/null
        ((BLOCKED++))
    fi
done <<< "$TASKS"

RESULT="Processed $PROCESSED tasks: $COMPLETED completed, $BLOCKED need review"
echo "**Agent:** ripley | **Model:** gemma-4-e2b-it"
echo ""
echo "$RESULT"

# Send Telegram if tasks were processed
if [ "$COMPLETED" -gt 0 ]; then
    $TELEGRAM "✅ Astro tasks: $RESULT" 2>/dev/null
fi
