#!/bin/bash

# Brave API Usage Tracker - Current Period Only
# Reports usage only for the current billing period
# Period = 31 days - reset_days (from X-RateLimit-Reset header)

set -euo pipefail

DB_FILE="/Users/keenaben/.openclaw/workspace/scripts/brave_api_usage.db"
LOG_FILE="/Users/keenaben/.openclaw/workspace/scripts/brave_api_usage.log"
CONFIG_FILE="${HOME}/.openclaw/openclaw.json"

MONTHLY_LIMIT=1000

# Logging function - uses local time
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date +"%Y-%m-%dT%H:%M:%S%z")
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Initialize database with both tables
init_db() {
    sqlite3 "$DB_FILE" <<EOF
CREATE TABLE IF NOT EXISTS api_calls (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    call_id TEXT UNIQUE NOT NULL,
    call_timestamp TEXT NOT NULL,
    session_file TEXT NOT NULL,
    query TEXT,
    added_timestamp TEXT DEFAULT (datetime('now', 'localtime'))
);

CREATE TABLE IF NOT EXISTS usage_summary (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    check_timestamp TEXT NOT NULL,
    check_date TEXT NOT NULL,
    period_start TEXT NOT NULL,
    period_end TEXT NOT NULL,
    period_days INTEGER NOT NULL,
    new_calls INTEGER NOT NULL,
    period_usage INTEGER NOT NULL,
    reset_days INTEGER NOT NULL,
    reset_date TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_api_calls_call_timestamp ON api_calls(call_timestamp);
CREATE INDEX IF NOT EXISTS idx_api_calls_added_timestamp ON api_calls(added_timestamp);
CREATE INDEX IF NOT EXISTS idx_api_calls_call_id ON api_calls(call_id);
EOF
}

# Get API key from config
get_api_key() {
    if [[ -f "$CONFIG_FILE" ]]; then
        awk '/"web"[[:space:]]*:/,/\}/' "$CONFIG_FILE" | \
            awk '/"search"[[:space:]]*:/,/\}/' | \
            grep '"apiKey"' | head -1 | sed 's/.*"apiKey"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/'
    else
        echo ""
    fi
}

# Fetch reset time from Brave API (returns seconds until reset)
fetch_reset_seconds() {
    local api_key
    api_key=$(get_api_key)
    
    if [[ -z "$api_key" ]]; then
        log "WARN" "No API key found, using default 31 days"
        echo "2678400"
        return
    fi
    
    local headers
    headers=$(curl -s -D - -H "Accept: application/json" \
        -H "X-Subscription-Token: $api_key" \
        "https://api.search.brave.com/res/v1/web/search?q=test&count=1&offset=0" \
        -o /dev/null 2>/dev/null || true)
    
    local reset
    reset=$(echo "$headers" | grep -i "X-RateLimit-Reset:" | head -1 | sed 's/.*, *\([0-9]*\).*/\1/' | tr -d ' \r')
    
    if [[ -z "$reset" || ! "$reset" =~ ^[0-9]+$ ]]; then
        log "WARN" "Could not fetch reset time, using default 31 days"
        echo "2678400"
        return
    fi
    
    echo "$reset"
}

# Calculate period start date based on reset_days
# Period = 31 days - reset_days ago, up to today
calculate_period_start() {
    local reset_days="$1"
    local period_days=$((31 - reset_days))
    
    # Calculate start date: today - period_days
    local start_date
    start_date=$(date -v-${period_days}d +"%Y-%m-%d" 2>/dev/null || date -d "-${period_days} days" +"%Y-%m-%d" 2>/dev/null)
    
    echo "$start_date"
}

# Extract all web_search calls from session files and return as tab-separated:
# call_id	timestamp	session_file	query
extract_all_api_calls() {
    local sessions_dir="${HOME}/.openclaw/agents/main/sessions"
    
    if [[ ! -d "$sessions_dir" ]]; then
        return
    fi
    
    for session in "$sessions_dir"/*.jsonl; do
        [[ -f "$session" ]] || continue
        
        local session_name
        session_name=$(basename "$session")
        
        # Parse each line looking for web_search tool calls
        while IFS= read -r line; do
            if [[ "$line" == *'"toolName":"web_search"'* ]]; then
                # Extract timestamp from the message timestamp field (not ts)
                local ts=""
                if [[ "$line" =~ \"timestamp\":[[:space:]]*\"([^\"]+)\" ]]; then
                    ts="${BASH_REMATCH[1]}"
                fi
                
                # Extract query (from the arguments)
                local query=""
                if [[ "$line" =~ \"query\":[[:space:]]*\"([^\"]+)\" ]]; then
                    query="${BASH_REMATCH[1]}"
                fi
                
                # Create unique call ID: session_name + timestamp + line hash
                local call_id
                call_id=$(echo "${session_name}:${ts}:${line:0:100}" | md5 -q 2>/dev/null || echo "${session_name}:${ts}" | shasum -a 256 | cut -d' ' -f1)
                
                # Output tab-separated
                printf '%s\t%s\t%s\t%s\n' "$call_id" "$ts" "$session_name" "$query"
            fi
        done < "$session"
    done
}

# Count API calls within a specific date range (inclusive)
count_calls_in_period() {
    local start_date="$1"  # YYYY-MM-DD
    local end_date="$2"    # YYYY-MM-DD
    
    # Convert to SQLite format and count
    # call_timestamp format varies, so we use substr to extract date portion
    local count
    count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM api_calls WHERE substr(call_timestamp, 1, 10) >= '$start_date' AND substr(call_timestamp, 1, 10) <= '$end_date';" 2>/dev/null || echo "0")
    
    echo "$count"
}

# Get count of all API calls in database
get_total_call_count() {
    sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM api_calls;" 2>/dev/null || echo "0"
}

# Check if this is first run
is_first_run() {
    local count
    count=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM usage_summary;" 2>/dev/null || echo "0")
    [[ "$count" == "0" ]]
}

# Create initial baseline entry
create_initial_entry() {
    log "INFO" "=== First Run - Creating Initial Entry ==="
    
    local reset_seconds
    reset_seconds=$(fetch_reset_seconds)
    
    local reset_days
    reset_days=$((reset_seconds / 86400))
    
    local reset_date
    reset_date=$(date -v+${reset_seconds}S +"%Y-%m-%d" 2>/dev/null || echo "unknown")
    
    # Calculate period
    local period_days=$((31 - reset_days))
    local period_start
    period_start=$(calculate_period_start "$reset_days")
    local period_end
    period_end=$(date +"%Y-%m-%d")
    
    local timestamp
    timestamp=$(date +"%Y-%m-%dT%H:%M:%S%z")
    local date_str
    date_str=$(date +%Y-%m-%d)
    
    # First, scan and insert all existing API calls
    log "INFO" "Scanning existing session files for baseline..."
    
    # Insert all existing calls
    extract_all_api_calls | while IFS=$'\t' read -r call_id ts session_file query; do
        query=$(echo "$query" | sed "s/'/''/g")
        sqlite3 "$DB_FILE" "INSERT OR IGNORE INTO api_calls (call_id, call_timestamp, session_file, query) VALUES ('$call_id', '$ts', '$session_file', '$query');" 2>/dev/null || true
    done
    
    local total_calls
    total_calls=$(get_total_call_count)
    
    # Count calls in current period
    local actual_period_usage
    actual_period_usage=$(count_calls_in_period "$period_start" "$period_end")
    
    log "INFO" "Found $total_calls total API calls in logs"
    log "INFO" "Current period ($period_start to $period_end): $actual_period_usage calls"
    
    # Use actual calls found as starting value (no baseline)
    local period_usage=$actual_period_usage
    
    # Create usage summary
    sqlite3 "$DB_FILE" "INSERT INTO usage_summary (check_timestamp, check_date, period_start, period_end, period_days, new_calls, period_usage, reset_days, reset_date) VALUES ('$timestamp', '$date_str', '$period_start', '$period_end', $period_days, $actual_period_usage, $period_usage, $reset_days, '$reset_date');"
    
    log "INFO" "Initial entry created:"
    log "INFO" "  - Period usage: $period_usage"
    log "INFO" "  - Period: $period_start to $period_end ($period_days days)"
    log "INFO" "  - Reset in: $reset_days days ($reset_date)"
}

# Main check function
check_usage() {
    log "INFO" "=== Brave API Usage Check ==="
    
    # Check if first run
    if is_first_run; then
        create_initial_entry
        show_report
        return
    fi
    
    # Get previous count
    local previous_count
    previous_count=$(get_total_call_count)
    
    log "INFO" "Previous total API calls in database: $previous_count"
    
    # Scan and insert new calls
    log "INFO" "Scanning for new API calls..."
    
    # Get all existing call_ids for comparison
    local existing_calls_file
    existing_calls_file=$(mktemp)
    sqlite3 "$DB_FILE" "SELECT call_id FROM api_calls;" 2>/dev/null | sort -u > "$existing_calls_file"
    
    # Find and insert new calls
    local temp_insert_file
    temp_insert_file=$(mktemp)
    local new_calls=0
    
    extract_all_api_calls | while IFS=$'\t' read -r call_id ts session_file query; do
        if ! grep -q "^${call_id}$" "$existing_calls_file" 2>/dev/null; then
            query=$(echo "$query" | sed "s/'/''/g")
            echo "INSERT OR IGNORE INTO api_calls (call_id, call_timestamp, session_file, query) VALUES ('$call_id', '$ts', '$session_file', '$query');"
            ((new_calls++))
            echo "$new_calls" > "${temp_insert_file}.count"
        fi
    done > "$temp_insert_file"
    
    # Execute inserts
    if [[ -s "$temp_insert_file" ]]; then
        sqlite3 "$DB_FILE" < "$temp_insert_file" 2>/dev/null || true
        new_calls=$(cat "${temp_insert_file}.count" 2>/dev/null || echo "0")
    fi
    
    rm -f "$temp_insert_file" "${temp_insert_file}.count" "$existing_calls_file"
    
    # Get updated count
    local current_count
    current_count=$(get_total_call_count)
    
    # Calculate actual new calls
    local actual_new=$((current_count - previous_count))
    
    log "INFO" "New API calls found: $actual_new"
    log "INFO" "Total API calls in database: $current_count"
    
    # Fetch current reset time
    local reset_seconds
    reset_seconds=$(fetch_reset_seconds)
    
    local reset_days
    reset_days=$((reset_seconds / 86400))
    
    local reset_date
    reset_date=$(date -v+${reset_seconds}S +"%Y-%m-%d" 2>/dev/null || echo "unknown")
    
    # Calculate period
    local period_days=$((31 - reset_days))
    local period_start
    period_start=$(calculate_period_start "$reset_days")
    local period_end
    period_end=$(date +"%Y-%m-%d")
    
    # Get previous period_usage as baseline
    local previous_period_usage
    previous_period_usage=$(sqlite3 "$DB_FILE" "SELECT period_usage FROM usage_summary ORDER BY check_timestamp DESC LIMIT 1;" 2>/dev/null || echo "0")
    
    # Calculate new period_usage: previous + new calls found + 1 for this API check
    local period_usage=$((previous_period_usage + actual_new + 1))
    
    # Insert usage summary
    local timestamp
    timestamp=$(date +"%Y-%m-%dT%H:%M:%S%z")
    local date_str
    date_str=$(date +%Y-%m-%d)
    
    sqlite3 "$DB_FILE" "INSERT INTO usage_summary (check_timestamp, check_date, period_start, period_end, period_days, new_calls, period_usage, reset_days, reset_date) VALUES ('$timestamp', '$date_str', '$period_start', '$period_end', $period_days, $actual_new, $period_usage, $reset_days, '$reset_date');"
    
    log "INFO" "Updated totals:"
    log "INFO" "  - New calls this run: $actual_new"
    log "INFO" "  - API check call: +1"
    log "INFO" "  - Previous period usage: $previous_period_usage"
    log "INFO" "  - New period usage: $period_usage"
    log "INFO" "  - Remaining: $((MONTHLY_LIMIT - period_usage))"
    log "INFO" "  - Period: $period_start to $period_end ($period_days days)"
    log "INFO" "  - Reset in: $reset_days days ($reset_date)"
}

# Show current report
show_report() {
    echo ""
    echo "=== BRAVE API USAGE REPORT ==="
    echo ""
    
    local latest
    latest=$(sqlite3 "$DB_FILE" "SELECT check_timestamp, period_usage, new_calls, reset_days, reset_date, period_start, period_end, period_days FROM usage_summary ORDER BY check_timestamp DESC LIMIT 1;" 2>/dev/null)
    
    if [[ -n "$latest" ]]; then
        local period_usage
        local reset_days
        local period_start
        local period_end
        local period_days
        period_usage=$(echo "$latest" | cut -d'|' -f2)
        reset_days=$(echo "$latest" | cut -d'|' -f4)
        reset_date=$(echo "$latest" | cut -d'|' -f5)
        period_start=$(echo "$latest" | cut -d'|' -f6)
        period_end=$(echo "$latest" | cut -d'|' -f7)
        period_days=$(echo "$latest" | cut -d'|' -f8)
        
        # Calculate totals (no baseline)
        local remaining=$((MONTHLY_LIMIT - period_usage))
        local pct_used
        pct_used=$(awk "BEGIN {printf \"%.1f\", 100.0 * $period_usage / $MONTHLY_LIMIT}")
        
        echo "Current Period Usage:"
        echo "  Period: $period_start to $period_end ($period_days days)"
        echo "  Usage this period: $period_usage"
        echo "  Total used: $period_usage / $MONTHLY_LIMIT (${pct_used}%)"
        echo "  Remaining: $remaining"
        echo "  Resets: $reset_date ($reset_days days)"
        echo ""
    fi
    
    echo "Recent usage checks:"
    sqlite3 "$DB_FILE" "SELECT check_timestamp, new_calls, period_usage, reset_days FROM usage_summary ORDER BY check_timestamp DESC LIMIT 10;" 2>/dev/null | column -t -s '|' || echo "No data"
    echo ""
}

# Show detailed call log
show_call_log() {
    echo ""
    echo "=== RECENT API CALLS ==="
    echo ""
    
    sqlite3 "$DB_FILE" "SELECT call_timestamp, session_file, substr(query, 1, 50), added_timestamp FROM api_calls ORDER BY call_timestamp DESC LIMIT 20;" 2>/dev/null | column -t -s '|' || echo "No calls logged"
    echo ""
}

# Show calls in current period
show_period_calls() {
    echo ""
    echo "=== API CALLS IN CURRENT PERIOD ==="
    echo ""
    
    # Get latest period info
    local latest
    latest=$(sqlite3 "$DB_FILE" "SELECT reset_days FROM usage_summary ORDER BY check_timestamp DESC LIMIT 1;" 2>/dev/null)
    
    if [[ -z "$latest" ]]; then
        echo "No data available. Run check first."
        return
    fi
    
    local reset_days="$latest"
    local period_days=$((31 - reset_days))
    local period_start
    period_start=$(calculate_period_start "$reset_days")
    local period_end
    period_end=$(date +"%Y-%m-%d")
    
    echo "Period: $period_start to $period_end ($period_days days)"
    echo ""
    
    sqlite3 "$DB_FILE" "SELECT call_timestamp, session_file, substr(query, 1, 50) FROM api_calls WHERE substr(call_timestamp, 1, 10) >= '$period_start' AND substr(call_timestamp, 1, 10) <= '$period_end' ORDER BY call_timestamp DESC LIMIT 30;" 2>/dev/null | column -t -s '|' || echo "No calls in current period"
    echo ""
}

# Manual update function
manual_update() {
    local additional_calls="${1:-0}"
    
    if [[ ! "$additional_calls" =~ ^[0-9]+$ ]]; then
        echo "Usage: $0 update <number>"
        echo "  Manually add API calls to the count"
        return 1
    fi
    
    log "INFO" "=== Manual Update ==="
    
    # Fetch current reset time
    local reset_seconds
    reset_seconds=$(fetch_reset_seconds)
    local reset_days=$((reset_seconds / 86400))
    local reset_date
    reset_date=$(date -v+${reset_seconds}S +"%Y-%m-%d" 2>/dev/null || echo "unknown")
    
    # Calculate period
    local period_days=$((31 - reset_days))
    local period_start
    period_start=$(calculate_period_start "$reset_days")
    local period_end
    period_end=$(date +"%Y-%m-%d")
    
    # Get current period usage
    local current_period_usage
    current_period_usage=$(count_calls_in_period "$period_start" "$period_end")
    
    local new_period_usage=$((current_period_usage + additional_calls))
    
    local timestamp
    timestamp=$(date +"%Y-%m-%dT%H:%M:%S%z")
    local date_str
    date_str=$(date +%Y-%m-%d)
    
    sqlite3 "$DB_FILE" "INSERT INTO usage_summary (check_timestamp, check_date, period_start, period_end, period_days, new_calls, period_usage, reset_days, reset_date) VALUES ('$timestamp', '$date_str', '$period_start', '$period_end', $period_days, $additional_calls, $new_period_usage, $reset_days, '$reset_date');"
    
    log "INFO" "Manually added $additional_calls calls"
    log "INFO" "New period usage: $new_period_usage"
}

# Reset database
reset_db() {
    log "WARN" "Resetting database..."
    rm -f "$DB_FILE"
    init_db
    create_initial_entry
}

# Main function
main() {
    local cmd="${1:-check}"
    
    # Ensure DB exists
    [[ ! -f "$DB_FILE" ]] && init_db
    
    case "$cmd" in
        check)
            check_usage
            show_report
            ;;
        update)
            manual_update "${2:-0}"
            show_report
            ;;
        report)
            show_report
            ;;
        calls)
            show_call_log
            ;;
        period)
            show_period_calls
            ;;
        reset)
            reset_db
            show_report
            ;;
        *)
            echo "Brave API Usage Tracker - Current Period Only"
            echo ""
            echo "Usage:"
            echo "  $0 check           - Check for new API calls and update count"
            echo "  $0 update <num>    - Manually add API calls"
            echo "  $0 report          - Show usage report"
            echo "  $0 calls           - Show all API calls"
            echo "  $0 period          - Show calls in current period only"
            echo "  $0 reset           - Reset database (back to baseline 109)"
            echo ""
            ;;
    esac
}

main "$@"
