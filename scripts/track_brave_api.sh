#!/bin/bash
# track_brave_api.sh - Track Brave API usage and reset periods
# Australian local time (Australia/Melbourne)

# Auto-source environment variables
source ~/.openclaw/.env 2>/dev/null

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DB_PATH="$SCRIPT_DIR/brave_api.db"
BRAVE_API_KEY="${BRAVE_API_KEY}"

# ============================================================
# Initialize subfunction
# Create SQLite database if it doesn't exist
# ============================================================
initialize() {
    if [ ! -f "$DB_PATH" ]; then
        sqlite3 "$DB_PATH" <<'EOF'
CREATE TABLE IF NOT EXISTS brave_api_usage (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date TEXT NOT NULL,
    used INTEGER DEFAULT 0,
    reset INTEGER DEFAULT 0,
    period_start TEXT DEFAULT ''
);
EOF
        echo "Database created: $DB_PATH"
    else
        echo "Database exists: $DB_PATH"
    fi
}

# ============================================================
# Date subfunction
# Get current time/date in Australian local time
# ============================================================
get_date() {
    date +"%Y-%m-%dT%H:%M:%S%z"
}

# ============================================================
# Get fresh API usage subfunction
# Count Brave API calls from OpenClaw logs since last entry
# ============================================================
get_fresh_usage() {
    local last_date
    local log_dir="$HOME/.openclaw/agents/main/sessions"
    
    # Get the last recorded date from database
    last_date=$(sqlite3 "$DB_PATH" "SELECT MAX(date) FROM brave_api_usage;" 2>/dev/null | tr -d '[:space:]')
    
    # If no entries, use epoch
    if [ -z "$last_date" ] || [ "$last_date" = "" ]; then
        last_date="1970-01-01T00:00:00+0000"
        echo "No prior entries found, counting from epoch" >&2
    else
        echo "Counting API calls since: $last_date" >&2
    fi
    
    # Convert last_date to Unix timestamp for comparison
    # Format in DB: 2026-03-26T06:33:26+1100
    # Convert to UTC Unix timestamp
    last_ts=$(date -j -f "%Y-%m-%dT%H:%M:%S%z" "$last_date" +%s 2>/dev/null || echo "0")
    
    # Count web_search tool calls AND direct Brave API calls via exec in all session logs
    local count=0
    
    # Look for entries with timestamps newer than last_date
    for logfile in "$log_dir"/*.jsonl; do
        if [ -f "$logfile" ]; then
            # Extract timestamp from each line and compare
            while IFS= read -r line; do
                # Check for web_search tool calls OR direct Brave API calls via exec
                if echo "$line" | grep -q '"toolName":"web_search"'; then
                    # Extract ISO timestamp from JSON line
                    # Format: "timestamp":"2026-03-15T21:21:40.646Z"
                    iso_ts=$(echo "$line" | grep -o '"timestamp":"[^"]*"' | head -1 | cut -d'"' -f4)
                    if [ -n "$iso_ts" ]; then
                        # Convert ISO timestamp to Unix seconds (log timestamps are UTC, stored as Z)
                        stripped=$(echo "$iso_ts" | sed 's/\(....-..-..T..:..:..\)[.].*/\1/')
                        log_ts=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "$stripped" +%s 2>/dev/null || echo "0")
                        if [ "$log_ts" -gt "$last_ts" ] 2>/dev/null; then
                            count=$((count + 1))
                        fi
                    fi
                elif echo "$line" | grep -q '"toolName":"exec"' && echo "$line" | grep -qi "api.search.brave.com\|X-Subscription-Token.*BRAVE"; then
                    # Direct Brave API calls via exec
                    iso_ts=$(echo "$line" | grep -o '"timestamp":"[^"]*"' | head -1 | cut -d'"' -f4)
                    if [ -n "$iso_ts" ]; then
                        stripped=$(echo "$iso_ts" | sed 's/\(....-..-..T..:..:..\)[.].*/\1/')
                        log_ts=$(TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%S" "$stripped" +%s 2>/dev/null || echo "0")
                        if [ "$log_ts" -gt "$last_ts" ] 2>/dev/null; then
                            count=$((count + 1))
                        fi
                    fi
                fi
            done < "$logfile"
        fi
    done
    
    echo "$count"
}

# ============================================================
# Get reset time subfunction
# Do a Brave API call to get X-RateLimit-Reset header
# Convert from seconds to days (uses monthly value, not per-second)
# ============================================================
get_reset_time() {
    local response
    local reset_seconds
    
    response=$(curl -s -D - "https://api.search.brave.com/res/v1/web/search?q=test&count=1" \
        -H "Accept: application/json" \
        -H "X-Subscription-Token: $BRAVE_API_KEY" 2>&1)
    
    # Get both reset values - take the third value (monthly limit in seconds)
    # Header format: X-RateLimit-Reset: 1, 534450 (per-second, monthly)
    reset_seconds=$(echo "$response" | grep -i "X-RateLimit-Reset:" | awk '{print $3}' | tr -d '\r')
    
    if [ -z "$reset_seconds" ]; then
        echo "0"
        return
    fi
    
    # Convert seconds to days
    local reset_days=$((reset_seconds / 86400))
    
    echo "$reset_days"
}

# ============================================================
# Calculate period start subfunction
# Use 31 minus Reset value to find days ago period started
# Convert to Australian local timestamp
# ============================================================
calculate_period_start() {
    local reset_days="$1"
    
    # Assume 31-day billing period
    local days_ago=$((31 - reset_days))
    
    if [ "$days_ago" -lt 0 ]; then
        days_ago=0
    fi
    
    # Get date that many days ago in Australian local time
    local period_start
    period_start=$(date -v-"${days_ago}d" +"%Y-%m-%dT%H:%M:%S%z" 2>/dev/null || \
                   date -d "${days_ago} days ago" +"%Y-%m-%dT%H:%M:%S%z" 2>/dev/null || \
                   echo "$(date +"%Y-%m-%dT%H:%M:%S%z")")
    
    echo "$period_start"
}

# ============================================================
# Database insert subfunction
# Insert a new row with Date, Used, Reset, Period start values
# ============================================================
db_insert() {
    local date_val="$1"
    local used_val="$2"
    local reset_val="$3"
    local period_start_val="$4"
    
    sqlite3 "$DB_PATH" <<EOF
INSERT INTO brave_api_usage (date, used, reset, period_start)
VALUES ('$date_val', $used_val, $reset_val, '$period_start_val');
EOF
    echo "Inserted: date=$date_val, used=$used_val, reset=$reset_val, period_start=$period_start_val"
}

# ============================================================
# Report API usage subfunction
# Return: Used: [sum] Reset: [value]
# ============================================================
report_usage() {
    local period_start
    local total_used
    local reset_val
    
    # Get the most recent period_start from database
    period_start=$(sqlite3 "$DB_PATH" "SELECT MAX(period_start) FROM brave_api_usage WHERE period_start != '';" 2>/dev/null)
    period_start=$(echo "$period_start" | tr -d '[:space:]')
    
    # Get most recent reset value
    reset_val=$(sqlite3 "$DB_PATH" "SELECT MAX(reset) FROM brave_api_usage;" 2>/dev/null | tr -d '[:space:]')
    
    if [ -z "$period_start" ] || [ "$period_start" = "" ]; then
        period_start="1970-01-01T00:00:00+0000"
    fi
    
    if [ -z "$reset_val" ] || [ "$reset_val" = "" ]; then
        reset_val="0"
    fi
    
    # Sum all used values where date >= period_start
    total_used=$(sqlite3 "$DB_PATH" "SELECT COALESCE(SUM(used), 0) FROM brave_api_usage WHERE date >= '$period_start';" 2>/dev/null)
    
    echo "Used: $total_used"
    echo "Reset: $reset_val days"
}

# ============================================================
# Main
# ============================================================
main() {
    local command="${1:-}"
    
    case "$command" in
        init)
            initialize
            ;;
        insert)
            initialize
            ;;
        report)
            ;;
        *)
            # Default: insert then report
            initialize
            ;;
    esac
    
    local current_date
    local fresh_usage
    local reset_days
    local period_start
    
    current_date=$(get_date)
    echo "Current date: $current_date"
    
    fresh_usage=$(get_fresh_usage)
    echo "Fresh usage: $fresh_usage"
    
    reset_days=$(get_reset_time)
    echo "Reset time: $reset_days days"
    
    period_start=$(calculate_period_start "$reset_days")
    echo "Period start: $period_start"
    
    if [ "$command" != "report" ]; then
        db_insert "$current_date" "$fresh_usage" "$reset_days" "$period_start"
        echo ""
    fi
    
    report_usage
}

main "$@"
