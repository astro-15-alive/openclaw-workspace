#!/bin/bash
set -e

# Generate new token
NEW_TOKEN=$(openssl rand -hex 32)

# Update secrets.json
python3 -c "
import json
with open('$HOME/.openclaw/secrets.json') as f:
    secrets = json.load(f)
secrets['OPENCLAW_GATEWAY_TOKEN'] = '$NEW_TOKEN'
with open('$HOME/.openclaw/secrets.json', 'w') as f:
    json.dump(secrets, f, indent=2)
"

# Restart gateway
openclaw gateway restart

# Log the rotation
echo "$(date): Rotated gateway token" >> /Users/keenaben/.openclaw/workspace/scripts/gateway_rotation.log
