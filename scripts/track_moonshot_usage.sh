#!/bin/bash
# track_moonshot_usage.sh - Get Moonshot/Kimi API balance in USD

# Auto-source environment variables
source ~/.openclaw/.env 2>/dev/null

MOONSHOT_API_KEY="${MOONSHOT_API_KEY}"

response=$(curl -s "https://api.moonshot.ai/v1/users/me/balance" \
    -H "Authorization: Bearer $MOONSHOT_API_KEY" \
    -H "Accept: application/json" 2>&1)

available=$(echo "$response" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('data', {}).get('available_balance', 0))" 2>/dev/null || echo "0")

printf "Available: %.2f USD\n" "$available"
