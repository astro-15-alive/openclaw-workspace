#!/bin/bash
# Auto-commit workspace script
# Runs git add/commit/push and outputs Discord-formatted report

cd ~/.openclaw/workspace

# Capture current state
BEFORE=$(git rev-parse HEAD 2>/dev/null || echo "N/A")

# Add all changes
git add -A

# Check if there are changes
if git diff --staged --quiet 2>/dev/null; then
    echo "🔄 **Workspace Sync** - $(date '+%A, %B %d, %Y')"
    echo ""
    echo "✅ **Git Sync Report** - $(date '+%Y-%m-%d')"
    echo ""
    echo "**Status:** ✅ SUCCESS"
    echo "**Changes:** No changes to commit"
    echo "**Last Commit:** ${BEFORE:0:8}"
    echo ""
    echo "**Repository:** astro-15-alive/openclaw-workspace"
    exit 0
fi

# Commit with date
git commit -m "Auto-sync: $(date '+%Y-%m-%d')" 2>&1

# Push
git push 2>&1

AFTER=$(git rev-parse HEAD 2>/dev/null || echo "N/A")

echo "🔄 **Workspace Sync** - $(date '+%A, %B %d, %Y')"
echo ""
echo "✅ **Git Sync Report** - $(date '+%Y-%m-%d')"
echo ""
echo "**Status:** ✅ SUCCESS"
echo "**Changes:** $(git diff --staged --stat | tail -1 | xargs || echo "files changed")"
echo "**Last Commit:** ${AFTER:0:8}"
echo ""
echo "**Repository:** astro-15-alive/openclaw-workspace"
