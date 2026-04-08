#!/bin/bash
# Health check script for Mac mini
# Returns JSON with health status - caller decides if alert is needed

source ~/.openclaw/secrets.env 2>/dev/null

ISSUES=()
WARNINGS=()

# 1. OpenClaw Gateway
if ! openclaw health >/dev/null 2>&1; then
    ISSUES+=("Gateway: not responding")
fi

# 2. Colima + Docker
if ! colima status >/dev/null 2>&1; then
    ISSUES+=("Colima: not running")
elif ! docker ps >/dev/null 2>&1; then
    ISSUES+=("Docker: not responding")
fi

# 3. SearXNG
if ! curl -s --connect-timeout 3 http://localhost:8888/health >/dev/null 2>&1; then
    ISSUES+=("SearXNG: not responding on port 8888")
fi

# 4. Disk space (root volume)
ROOT_FREE=$(df / | tail -1 | awk '{print $4}')
ROOT_TOTAL=$(df / | tail -1 | awk '{print $2}')
ROOT_PCT=$(( ROOT_FREE * 100 / ROOT_TOTAL ))
if [ "$ROOT_PCT" -lt 10 ]; then
    ISSUES+=("Disk: only ${ROOT_PCT}% free on root volume (${ROOT_FREE} blocks)")
elif [ "$ROOT_PCT" -lt 20 ]; then
    WARNINGS+=("Disk: ${ROOT_PCT}% free on root volume")
fi

# 5. Last backup check
LAST_BACKUP=$(ls -t ~/.openclaw/backup/*.json 2>/dev/null | head -1)
if [ -n "$LAST_BACKUP" ]; then
    BACKUP_AGE=$(($(date +%s) - $(stat -f %m "$LAST_BACKUP" 2>/dev/null || stat -c %Y "$LAST_BACKUP" 2>/dev/null)))
    BACKUP_HOURS=$((BACKUP_AGE / 3600))
    if [ "$BACKUP_HOURS" -gt 48 ]; then
        ISSUES+=("Backup: last backup was ${BACKUP_HOURS}h ago (${LAST_BACKUP})")
    elif [ "$BACKUP_HOURS" -gt 28 ]; then
        WARNINGS+=("Backup: last backup was ${BACKUP_HOURS}h ago")
    fi
else
    ISSUES+=("Backup: no backup files found")
fi

# Output
if [ ${#ISSUES[@]} -eq 0 ] && [ ${#WARNINGS[@]} -eq 0 ]; then
    echo "OK"
elif [ ${#ISSUES[@]} -eq 0 ]; then
    echo "WARN: $(printf '%s; ' "${WARNINGS[@]}")"
else
    echo "FAIL: $(printf '%s; ' "${ISSUES[@]}")"
fi
