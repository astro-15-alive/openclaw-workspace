#!/bin/bash
# Auto-commit workspace script
# Runs git add/commit/push and outputs Discord-formatted report

cd ~/.openclaw/workspace

# Capture current state
BEFORE=$(git rev-parse HEAD 2>/dev/null || echo "N/A")

# Add all changes (--ignore-errors skips nested git repo directories)
git add --ignore-errors -- . >/dev/null 2>&1
ADD_EXIT=$?

# Check if add had real errors vs partial skips
if [ $ADD_EXIT -ne 0 ]; then
    STAGED=$(git diff --staged --name-only 2>/dev/null | wc -l | tr -d ' ')
    if [ "$STAGED" -eq 0 ] || [ -z "$STAGED" ]; then
        echo "🔄 **Workspace Sync** - $(date '+%A, %B %d, %Y')"
        echo "**Agent:** astro | **Model:** minimax-m2.7"
        echo ""
        echo "**Status:** ✅ SUCCESS"
        echo "**Changes:** Nothing to commit — working tree clean (or only nested repo directories changed)"
        echo "**Last Commit:** ${BEFORE:0:8}"
        echo ""
        echo "**Repository:** astro-15-alive/openclaw-workspace"
        exit 0
    fi
fi

# Check if there are changes
if git diff --staged --quiet 2>/dev/null; then
    echo "🔄 **Workspace Sync** - $(date '+%A, %B %d, %Y')"
    echo "**Agent:** astro | **Model:** minimax-m2.7"
    echo ""
    echo "**Status:** ✅ SUCCESS"
    echo "**Changes:** No changes to commit"
    echo "**Last Commit:** ${BEFORE:0:8}"
    echo ""
    echo "**Repository:** astro-15-alive/openclaw-workspace"
    exit 0
fi

# Commit with date (with retry)
MAX_ATTEMPTS=3
ATTEMPT=0
COMMIT_CODE=1

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    ATTEMPT=$((ATTEMPT + 1))
    COMMIT_OUTPUT=$(git commit -m "Auto-sync: $(date '+%Y-%m-%d')" 2>&1)
    COMMIT_CODE=$?
    if [ $COMMIT_CODE -eq 0 ]; then
        break
    fi
    sleep 1
done

if [ $COMMIT_CODE -ne 0 ]; then
    echo "🔄 **Workspace Sync** - $(date '+%A, %B %d, %Y')"
    echo "**Agent:** astro | **Model:** minimax-m2.7"
    echo ""
    echo "**Status:** ❌ FAILED (commit retry exhausted)"
    echo "**Error:** $COMMIT_OUTPUT"
    echo "**Last Commit:** ${BEFORE:0:8}"
    exit 1
fi

# Push
PUSH_OUTPUT=$(git push 2>&1)
PUSH_CODE=$?

AFTER=$(git rev-parse HEAD 2>/dev/null || echo "N/A")

if [ $PUSH_CODE -ne 0 ]; then
    echo "🔄 **Workspace Sync** - $(date '+%A, %B %d, %Y')"
    echo "**Agent:** astro | **Model:** minimax-m2.7"
    echo ""
    echo "**Status:** ❌ FAILED (push failed)"
    echo "**Error:** $PUSH_OUTPUT"
    echo "**Last Commit:** ${AFTER:0:8}"
    exit 1
fi

echo "🔄 **Workspace Sync** - $(date '+%A, %B %d, %Y')"
echo "**Agent:** astro | **Model:** minimax-m2.7"
echo ""
echo "**Status:** ✅ SUCCESS"
echo "**Changes:** $(git diff --staged --stat | tail -1 | xargs || echo "files changed")"
echo "**Last Commit:** ${AFTER:0:8}"
echo ""
echo "**Repository:** astro-15-alive/openclaw-workspace"
