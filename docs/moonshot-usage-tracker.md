# Moonshot/Kimi API Usage Tracker

Tracks token usage and estimates costs from OpenClaw session logs.

## How It Works

1. **Parses OpenClaw session logs** (`~/.openclaw/agents/main/sessions/*.jsonl`)
2. **Extracts token usage** for Moonshot/Kimi API calls
3. **Calculates costs** based on pricing:
   - Input: $0.45 per million tokens
   - Output: $2.20 per million tokens
   - Cache read: $0.45 per million tokens (estimated)
4. **Tracks against monthly budget** (default: $50)
5. **Alerts at 90%**, **disables at 99%** of budget

## Current Usage

```
Requests: 292
Tokens: 18,550,018 (5.1M input, 86K output, 17.9M cache)
Cost: $8.50
Budget: 17.0% of $50
Status: ACTIVE ✅
```

## Commands

```bash
# Check usage (default)
./track_moonshot_usage.sh check

# Show report
./track_moonshot_usage.sh report

# Set monthly budget
./track_moonshot_usage.sh setbudget 100

# Manual enable/disable
./track_moonshot_usage.sh enable
./track_moonshot_usage.sh disable
```

## Files

- `track_moonshot_usage.sh` - Main script
- `moonshot_usage.db` - SQLite database
- `moonshot_usage.log` - Execution log
- `moonshot-crontab.txt` - Cron job template

## Cron Job

```bash
# Daily at 6am
0 6 * * * /Users/keenaben/.openclaw/workspace/scripts/track_moonshot_usage.sh check >> /Users/keenaben/.openclaw/workspace/scripts/moonshot_usage_cron.log 2>&1
```

## Database Schema

### usage table
- timestamp, date, session_id, model
- input_tokens, output_tokens, cache_read_tokens, cache_write_tokens
- cost_input, cost_output, cost_cache, cost_total

### daily_summary table
- date, total_requests, total_tokens, total_cost, budget_pct

## Thresholds

| Threshold | Action |
|-----------|--------|
| 90% of budget | Send alert |
| 99% of budget | Disable Moonshot API |
| <99% of budget | Re-enable API |
