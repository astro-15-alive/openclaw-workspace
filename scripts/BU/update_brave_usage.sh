#!/bin/bash

# Manual Brave API Usage Update
# Run this after checking your usage on the Brave dashboard
# Usage: ./update_brave_usage.sh <number>

set -euo pipefail

SCRIPT_DIR="/Users/keenaben/.openclaw/workspace/scripts"

if [[ $# -ne 1 || ! "$1" =~ ^[0-9]+$ ]]; then
    echo "Usage: $0 <number>"
    echo "  Update Brave API usage with current count from dashboard"
    echo "  Example: $0 91"
    echo ""
    echo "To check your current usage:"
    echo "  1. Go to https://api.search.brave.com/app/"
    echo "  2. Log in with: bkeenan@gmail.com"
    echo "  3. Note the 'X of 1,000 requests used' number"
    echo "  4. Run: $0 <that number>"
    exit 1
fi

USAGE="$1"

echo "Updating Brave API usage to: $USAGE/1000"
bash "$SCRIPT_DIR/track_brave_api.sh" init "$USAGE"

echo ""
echo "Done! The daily briefing will now show:"
echo "  Used: $USAGE/1000"
echo "  Remaining: $((1000 - USAGE))"
