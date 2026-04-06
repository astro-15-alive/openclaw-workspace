# Directory Monitor

A Python script that monitors a directory for file changes and logs them to a SQLite database.

## Features

- **Real-time monitoring** using the `watchdog` library
- **SQLite logging** with proper schema and indexes
- **Comprehensive error handling** and logging
- **Command-line interface** with multiple options
- **Query capabilities** for stats and recent events

## Installation

```bash
# Install required dependency
pip install watchdog
```

## Usage

### Basic Usage

```bash
# Monitor a directory
python dir_monitor.py /path/to/watch

# Monitor with debug logging
python dir_monitor.py /path/to/watch --log-level DEBUG

# Non-recursive monitoring
python dir_monitor.py /path/to/watch --no-recursive
```

### Advanced Options

```bash
# Custom database path
python dir_monitor.py /path/to/watch --db-path /custom/path.db

# Log to file
python dir_monitor.py /path/to/watch --log-file /var/log/monitor.log

# Ignore patterns
python dir_monitor.py /path/to/watch --ignore-pattern "*.tmp" --ignore-pattern "*.log"
```

### Query Database

```bash
# Show statistics
python dir_monitor.py /path/to/watch --stats

# Show recent events
python dir_monitor.py /path/to/watch --recent 20
```

## Database Schema

```sql
file_events (
    id INTEGER PRIMARY KEY,
    timestamp TEXT,
    event_type TEXT,        -- created, modified, moved, deleted
    src_path TEXT,
    dest_path TEXT,         -- for moved events
    is_directory INTEGER,
    file_size INTEGER,      -- for files (when available)
    created_at TEXT
)
```

## Event Types

- `created` - New file or directory created
- `modified` - File or directory modified
- `moved` - File or directory renamed/moved
- `deleted` - File or directory deleted

## Default Paths

- **Database**: `~/.dir_monitor/events.db`
- **Log file**: (stdout by default, or specify with `--log-file`)
