#!/bin/bash
# track_xai_usage.sh - Check xAI API balance via management API

set -a
source ~/.openclaw/.env 2>/dev/null
set +a

XAI_MANAGEMENT_KEY="${XAI_MANAGEMENT_KEY}"
XAI_TEAM_ID="${XAI_TEAM_ID}"

response=$(curl -s "https://management-api.x.ai/v1/billing/teams/$XAI_TEAM_ID/prepaid/balance" \
    -H "Authorization: Bearer $XAI_MANAGEMENT_KEY" \
    -H "Content-Type: application/json" 2>&1)

# Parse total and createTime from response
total=$(echo "$response" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('total',{}).get('val','N/A'))" 2>/dev/null || echo "N/A")
last_update=$(echo "$response" | python3 -c "
import sys,json
from datetime import datetime
from zoneinfo import ZoneInfo
d=json.load(sys.stdin)
changes=d.get('changes',[])
if changes:
    ts=changes[0].get('createTime','N/A')
    if ts != 'N/A':
        dt=datetime.fromisoformat(ts.replace('Z','+00:00'))
        aus=ZoneInfo('Australia/Melbourne')
        dt_aus=dt.astimezone(aus)
        print(dt_aus.strftime('%d %b %Y, %H:%M %Z'))
    else:
        print('N/A')
else:
    print('N/A')
" 2>/dev/null || echo "N/A")

# Convert credits to USD (divide by 100) and format
if [ "$total" != "N/A" ]; then
    total_usd=$(echo "scale=2; $total / 100" | bc 2>/dev/null | tr -d '-' || echo "N/A")
    echo "💎 **xAI Balance**"
    echo "• Total: \$$total_usd USD"
    echo "• Last Update: $last_update"
fi
