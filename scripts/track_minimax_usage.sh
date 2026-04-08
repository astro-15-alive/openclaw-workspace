#!/bin/bash
# track_minimax_usage.sh - Track MiniMax M2.7 API usage from session logs

# Auto-source environment variables
source ~/.openclaw/secrets.env 2>/dev/null

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DB_PATH="$SCRIPT_DIR/minimax_usage.db"

# Initialize database
sqlite3 "$DB_PATH" <<'EOF'
CREATE TABLE IF NOT EXISTS minimax_usage (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date TEXT NOT NULL,
    requests INTEGER DEFAULT 0,
    cost REAL DEFAULT 0
);
EOF

# Get current date
current_date=$(date +"%Y-%m-%dT%H:%M:%S%z")

# Get last recorded date
last_date=""
if [ -f "$DB_PATH" ]; then
    last_date=$(sqlite3 "$DB_PATH" "SELECT MAX(date) FROM minimax_usage;" 2>/dev/null | tr -d '[:space:]')
fi

# Use python to parse logs
python3 - "$current_date" "$DB_PATH" "$last_date" << 'PYEOF'
import sys
import os
import re
from datetime import datetime

current_date = sys.argv[1]
db_path = sys.argv[2]
last_date = sys.argv[3] if len(sys.argv) > 3 and sys.argv[3] else None

last_ts = 0
if last_date:
    try:
        dt = datetime.fromisoformat(last_date.replace('+0000', '+00:00').replace('+1100', '+11:00'))
        last_ts = int(dt.timestamp())
    except Exception as e:
        pass

log_dir = os.path.expanduser("~/.openclaw/agents/main/sessions")

new_requests = 0
total_cost = 0.0

for filename in os.listdir(log_dir):
    if filename.endswith(".jsonl"):
        filepath = os.path.join(log_dir, filename)
        try:
            with open(filepath, 'r') as f:
                for line in f:
                    if '"provider":"minimax"' in line:
                        ts_match = re.search(r'"timestamp":"([^"]+)"', line)
                        is_new = False
                        if ts_match:
                            ts_str = ts_match.group(1).split('.')[0]
                            try:
                                dt = datetime.fromisoformat(ts_str.replace('Z', '+00:00'))
                                log_ts = int(dt.timestamp())
                                if log_ts > last_ts:
                                    new_requests += 1
                                    is_new = True
                            except:
                                pass
                        
                        # Only add cost for new requests
                        if is_new:
                            cost_match = re.search(r'"cost":\s*\{[^}]*"total":\s*([0-9.]+)', line)
                            if cost_match:
                                try:
                                    total_cost += float(cost_match.group(1))
                                except:
                                    pass
        except:
            pass

# Insert new record
import sqlite3
conn = sqlite3.connect(db_path)
conn.execute("INSERT INTO minimax_usage (date, requests, cost) VALUES (?, ?, ?)", 
             (current_date, new_requests, total_cost))
conn.commit()
conn.close()

# Calculate period total
conn = sqlite3.connect(db_path)
cursor = conn.execute("SELECT COALESCE(SUM(cost), 0), COALESCE(SUM(requests), 0) FROM minimax_usage WHERE date >= '2026-03-01'")
row = cursor.fetchone()
period_cost = row[0]
period_requests = row[1]
conn.close()

print(f"MiniMax M2.7 Usage (since Mar 1):")
print(f"Requests: {period_requests}")
print(f"Cost: ${period_cost:.4f} USD")
PYEOF
