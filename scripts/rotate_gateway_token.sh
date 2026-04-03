#!/bin/bash
set -e

# Generate new token
NEW_TOKEN=$(openssl rand -hex 32)

# Update .env file
sed -i '' "s/OPENCLAW_GATEWAY_TOKEN=.*/OPENCLAW_GATEWAY_TOKEN=$NEW_TOKEN/" ~/.openclaw/.env

# Restart gateway
openclaw gateway restart

# Log the rotation
echo "$(date): Rotated gateway token" >> /Users/keenaben/.openclaw/workspace/scripts/gateway_rotation.log
