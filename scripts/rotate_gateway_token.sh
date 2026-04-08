#!/bin/bash
set -e

set -a
source ~/.openclaw/.env 2>/dev/null
set +a

# Generate new token
NEW_TOKEN=$(openssl rand -hex 32)

# Update .env file
sed -i '' "s/^OPENCLAW_GATEWAY_TOKEN=.*/OPENCLAW_GATEWAY_TOKEN=$NEW_TOKEN/" ~/.openclaw/.env

# Update openclaw.json config
openclaw config set gateway.auth.token "$NEW_TOKEN" 2>/dev/null || true

# Restart gateway
openclaw gateway restart

# Log the rotation
echo "$(date): Rotated gateway token" >> /Users/keenaben/.openclaw/workspace/scripts/gateway_rotation.log
