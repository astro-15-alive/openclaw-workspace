#!/bin/bash
# track_openrouter_usage.sh - Get OpenRouter API usage and credit balance

# Auto-source environment variables
set -a
source ~/.openclaw/.env 2>/dev/null
set +a

OPENROUTER_API_KEY="${OPENROUTER_API_KEY}"

response=$(curl -s "https://openrouter.ai/api/v1/credits" \
    -H "Authorization: Bearer $OPENROUTER_API_KEY" \
    -H "Accept: application/json" 2>&1)

balance=$(echo "$response" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('data', {}).get('total_credits', 0) - d.get('data', {}).get('total_usage', 0))" 2>/dev/null || echo "0")
usage=$(echo "$response" | python3 -c "import sys, json; d=json.load(sys.stdin); print(d.get('data', {}).get('total_usage', 0))" 2>/dev/null || echo "0")

printf "Balance: %.2f USD\n" "$balance"
printf "Usage: %.2f USD\n" "$usage"
