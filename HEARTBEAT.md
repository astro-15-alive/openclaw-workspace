# HEARTBEAT.md - Periodic Checks

## Email Check (High Priority)

**Action:** Check agentmail inbox for new emails
**Command to run:**
```bash
python3 << 'PYEOF'
import json
import os
from datetime import datetime, timedelta

# Load API key from secrets.json
with open(os.path.expanduser('~/.openclaw/secrets.json')) as f:
    secrets = json.load(f)
os.environ['AGENTMAIL_API_KEY'] = secrets['AGENTMAIL_API_KEY']

from agentmail import AgentMail

client = AgentMail(api_key=os.environ['AGENTMAIL_API_KEY'])
inbox_id = 'astro.15.alive@agentmail.to'

# Get recent messages (last 60 min)
messages = client.inboxes.messages.list(inbox_id=inbox_id, limit=10)
new_emails = []

for msg in messages.messages:
    # Check if received in last 60 minutes
    from datetime import datetime, timedelta
    now = datetime.now(msg.created_at.tzinfo)
    if now - msg.created_at < timedelta(minutes=65):  # 65 min buffer
        new_emails.append(f"From: {msg.from_}\nSubject: {msg.subject}")

if new_emails:
    print("NEW_EMAILS_FOUND")
    for email in new_emails:
        print(email)
        print("---")
else:
    print("NO_NEW_EMAILS")
PYEOF
```

**If NEW_EMAILS_FOUND:**
1. Send Telegram message to BK using:
   ```bash
   ~/.openclaw/workspace/scripts/send-telegram.sh "📬 New email(s) in inbox:\n\n[email list]"
   ```
2. Include sender and subject for each new email

**If NO_NEW_EMAILS:**
- Continue with other checks

## Other Checks (Rotate Through)

### Calendar
**Action:** Check Apple Calendar for upcoming events (next 24h)
**Command:**
```bash
icalBuddy -po eventTitle,startDate,notes -n 5 -b "> " -ic "Calendar" eventsToday+1 | head -20
```
**If events found:** → Include in proactive update
**If no events:** → Skip

### Tasks  

## Response Rules

- **Found something actionable?** → Send alert to main chat, include details
- **Nothing urgent?** → Reply `HEARTBEAT_OK`
- **Multiple items?** → Batch into one message, prioritize by urgency
