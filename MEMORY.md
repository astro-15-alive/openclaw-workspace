# MEMORY.md - Long-Term Memory

## Critical Procedures

### Daily Midnight Task Review

**Cron Job:** Daily at midnight (Australia/Melbourne)

**Workflow:**
1. `remindctl list astro` — check for open tasks
2. Work through tasks I can complete
3. For each task:
   - Add notes: `remindctl edit <id> --notes "<what I did or questions>"`
   - If completed and verified: `remindctl edit <id> --list completed`
4. If any tasks completed, send Telegram to Ben (telegram:7422005247):
   - "Completed [N] task(s) from astro list: [task titles]"
5. Only work on tasks from the astro list

---

## Contact Information

| Person | Email | Notes |
|--------|-------|-------|
| BK (Ben) | bkeenan@gmail.com | Primary human, safe to email without asking |
| RM | — | BK's fiancée |

---

## System Configuration

---

## Local LLM Models

### Available Models
| Model | Provider | Context | Best For |
|-------|----------|---------|----------|
| qwen3.5:9b | Ollama | 64K | General tasks, coding |
| qwen3.5:2b | Ollama | 64K | Fast responses |
| qwen3.5-9b-mlx | LM Studio | 64K | High-quality local inference |
| gemma-3-4b | LM Studio | 20K | Balanced speed/quality |
| kimi-k2.5 | Moonshot | 256K | Best quality, images |

### Model Aliases (in config)
- `gemma3 4b MLX` → lmstudio/google/gemma-3-4b
- `qwen3.5 9b MLX` → lmstudio/qwen3.5-9b-mlx
- `Kimi` → moonshot/kimi-k2.5

### Switching Models
```bash
# Temporary (this session only)
openclaw run --model lmstudio/qwen3.5-9b-mlx

# Per-session override
/model ollama/qwen3.5:9b
```

---

## Discord Channels

| Channel | ID | Purpose |
|---------|----|---------|
| #system | 1486649694661906543 | Backups, session audits, system reports |
| #daily-briefing | 1486100377056182362 | Morning briefings |
| #tasks | 1486495544305127455 | Astro task notifications |

---

## Important Paths

| Location | Purpose |
|----------|---------|
| `~/.openclaw/openclaw.json` | Main config file |
| `~/.openclaw/workspace/` | Working directory |
| `~/.openclaw/workspace/docs/` | Documentation |
| `~/.openclaw/workspace/memory/` | Daily logs |
| `~/.openclaw/workspace/backup/` | Backup scripts |
| `~/Library/Application Support/gogcli/` | Google auth credentials |

---

## Cron Jobs

| Name | Schedule | Task |
|------|----------|------|
| software-update-checker | Daily @ 1 AM | Check Homebrew/npm/Ollama updates (OpenClaw reported only — manual update) |
| openclaw-backup | Daily @ midnight | Backup workspace |
| openclaw-config-backup | Daily @ midnight | Backup openclaw.json |
| brave-usage-tracker | Daily @ midnight | Track Brave API usage, alert at 90%, disable at 99% |

## Brave API Usage Monitoring

**Location:** `scripts/track_brave_usage.sh`

**Approach:** Tracks usage by counting `web_search` tool calls from OpenClaw session logs

**How It Works:**
1. **Counts requests** - Parses `~/.openclaw/agents/main/sessions/*.jsonl` for `"toolName":"web_search"`
2. **Estimates quota** - Based on $5/month credit ≈ 1,000 requests
3. **Calculates usage %** - (requests / 1000) × 100
4. **Auto-manages API** - Disables at 99%, re-enables below 99%

**Features:**
- **Automatic counting** - No manual input needed
- **Cost estimation** - $5 per 1,000 requests
- **Alerts at 90%** usage (Telegram notification)
- **Auto-disables at 99%** (modifies openclaw.json)
- **Auto-re-enables below 99%**
- Stores data in SQLite with daily tracking

**Commands:**
```bash
./track_brave_usage.sh check    # Count requests and apply thresholds (default)
./track_brave_usage.sh report   # Show usage report
./track_brave_usage.sh update N # Manually set request count
./track_brave_usage.sh enable   # Manually enable API
./track_brave_usage.sh disable  # Manually disable API
```

**Thresholds:**
- Alert: 90% (~900 requests)
- Disable: 99% (~990 requests)
- Re-enable: <99%

**Cron Job:**
```bash
# Daily at 6am
0 6 * * * /Users/keenaben/.openclaw/workspace/scripts/track_brave_usage.sh check >> /Users/keenaben/.openclaw/workspace/scripts/brave_usage_cron.log 2>&1
```

**Files:**
- `scripts/track_brave_usage.sh` - Main script
- `scripts/brave_usage.db` - SQLite database
- `scripts/brave_usage.log` - Execution log
- `scripts/config_backups/` - Config backups before changes
- `scripts/.alert_*.txt` - Alert notification files

**Note:** Since Brave API headers don't return monthly quotas for credit-based plans, this tracker counts actual usage from OpenClaw logs. Current count: 18 requests.

---

## Moonshot/Kimi API Usage Monitoring

**Location:** `scripts/track_moonshot_usage.sh`

**Approach:** Parses token usage from OpenClaw session logs

**How It Works:**
1. **Parses session logs** - Extracts `"provider":"moonshot"` entries
2. **Counts tokens** - Input, output, cache read tokens
3. **Calculates costs** - $0.45/M input, $2.20/M output
4. **Tracks budget** - Default $50/month
5. **Auto-manages API** - Disables at 99% budget, re-enables below

**Current Usage:**
```
Requests: 292
Tokens: 18.5M (5.1M input, 86K output, 17.9M cache)
Cost: $8.50
Budget: 17% of $50
```

**Commands:**
```bash
./track_moonshot_usage.sh check      # Parse logs and update
./track_moonshot_usage.sh report     # Show report
./track_moonshot_usage.sh setbudget  # Set monthly budget
./track_moonshot_usage.sh enable     # Manually enable
./track_moonshot_usage.sh disable    # Manually disable
```

**Thresholds:**
- Alert: 90% of budget ($45)
- Disable: 99% of budget ($49.50)
- Re-enable: <99%

**Cron Job:**
```bash
# Daily at 6am
0 6 * * * /Users/keenaben/.openclaw/workspace/scripts/track_moonshot_usage.sh check >> /Users/keenaben/.openclaw/workspace/scripts/moonshot_usage_cron.log 2>&1
```

**Files:**
- `scripts/track_moonshot_usage.sh` - Main script
- `scripts/moonshot_usage.db` - SQLite database
- `scripts/moonshot_usage.log` - Execution log
- `docs/moonshot-usage-tracker.md` - Documentation

---

## Lessons Learned

### OAuth Redirect URI Issue (2026-03-15)
**Problem:** Browser authorization failed with "invalid redirect_uri"
**Root cause:** Google Cloud Console had `http://localhost` but gog needs `http://127.0.0.1:PORT/oauth2/callback`
**Solution:** Update Authorized redirect URIs in Cloud Console, re-download JSON, use file-based keyring

### Always Use Local Time (2026-03-17)
**Lesson:** Timestamps should always use local time (Australia/Melbourne) not UTC
**Applies to:**
- Database timestamps
- Log files
- Reports
- Any user-facing dates/times

**Implementation:**
- Use `date +"%Y-%m-%dT%H:%M:%S%z"` instead of `date -u +"%Y-%m-%dT%H:%M:%SZ"`
- Use `datetime('now', 'localtime')` in SQLite instead of `datetime('now')`
- Store timezone offset in timestamps (e.g., `+1100` for AEDT)

### Always Verify Before Confirming (2026-03-28)
**Lesson:** Always check/verify information before confirming it to the user
**Applies to:**
- Cron job status and configurations
- Task completion statuses
- System states and settings
- Any information the user asks about

**Implementation:**
- When asked about cron job status, actually check the current state rather than assuming
- When told something was updated, verify the change actually took effect
- When confirming a task was completed, check the actual task state
- Use tools (cron list, remindctl, exec) to verify, don't just trust the last reported state

### Always Verify Before Editing (2026-03-28)
**Lesson:** Always check/read something first before editing it, especially cron jobs. Things may have been edited since the last time I saw them.
**Applies to:**
- Cron job definitions (always read current state via `cron list` before updating)
- Configuration files
- Scripts and skill definitions
- Any file that might have been modified since last read

**Implementation:**
- Before updating a cron job, use `cron list` to get the current definition
- Before editing any file, read it first to see its current content
- Don't assume the last version I saw is still the current version

---

*Last updated: 2026-03-28*
