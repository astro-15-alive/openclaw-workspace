# Brave API Usage Tracker

Simple manual-update usage tracker for Brave Search API.

## How It Works

Since Brave doesn't provide a public API for usage data, you manually update the tracker with your usage from the dashboard.

**Workflow:**
1. Check your usage at: https://api-dashboard.search.brave.com/app/usage
2. Run: `./track_brave_usage.sh update <requests_used>`
3. Script alerts at 90% and disables API at 99%
4. Script re-enables API when usage drops below 95%

## Commands

```bash
# Update usage (triggers alerts/disable/enable as needed)
./track_brave_usage.sh update 850

# Update with custom limit
./track_brave_usage.sh update 850 2000

# Show usage report
./track_brave_usage.sh report

# Check if API is enabled
./track_brave_usage.sh check

# Manual enable/disable
./track_brave_usage.sh enable
./track_brave_usage.sh disable
```

## Thresholds

| Threshold | Action |
|-----------|--------|
| 90% | Send alert notification |
| 99% | Disable Brave API |
| <95% | Re-enable Brave API (if was disabled) |

## Files

- `track_brave_usage.sh` - Main script
- `brave_usage.db` - SQLite database
- `brave_usage.log` - Execution log
- `config_backups/` - Config backups before changes
- `.alert_*.txt` - Alert notification files

## Database Schema

```sql
usage table:
  - timestamp: When recorded
  - date: Date (YYYY-MM-DD)
  - used: Requests used
  - request_limit: Monthly limit (default 1000)
  - pct: Usage percentage
  - cost: Estimated cost ($5 per 1000)

state table:
  - disabled: 1 if API disabled
  - alert_90_sent: 1 if 90% alert sent
  - last_update: Last update timestamp
```

## Cron Job (Optional)

If you want a daily reminder to check usage:

```bash
# Add to crontab - daily at 6am
0 6 * * * echo "Check Brave API usage: https://api-dashboard.search.brave.com/app/usage" >> ~/.openclaw/workspace/scripts/brave_usage.log 2>&1
```

But manual updates work best since you need to visit the dashboard anyway.
