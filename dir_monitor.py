#!/usr/bin/env python3
"""
Directory Monitor - Watches a directory for file changes and logs them to SQLite.

Usage:
    python dir_monitor.py /path/to/watch
    python dir_monitor.py /path/to/watch --db-path /custom/path.db --log-level DEBUG
"""

import os
import sys
import time
import sqlite3
import argparse
import logging
from datetime import datetime
from pathlib import Path
from typing import Optional
from contextlib import contextmanager
from dataclasses import dataclass

# Third-party imports
try:
    from watchdog.observers import Observer
    from watchdog.events import FileSystemEventHandler, FileSystemEvent
except ImportError:
    print("Error: watchdog library required. Install with: pip install watchdog")
    sys.exit(1)


# =============================================================================
# Configuration & Constants
# =============================================================================

DEFAULT_DB_PATH = Path.home() / ".dir_monitor" / "events.db"
DEFAULT_LOG_PATH = Path.home() / ".dir_monitor" / "monitor.log"


# =============================================================================
# Data Models
# =============================================================================

@dataclass
class FileEvent:
    """Represents a file system event."""
    timestamp: datetime
    event_type: str
    src_path: str
    dest_path: Optional[str]
    is_directory: bool
    file_size: Optional[int]


# =============================================================================
# Database Manager
# =============================================================================

class DatabaseManager:
    """Manages SQLite database operations for file events."""
    
    SCHEMA = """
    CREATE TABLE IF NOT EXISTS file_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL,
        event_type TEXT NOT NULL,
        src_path TEXT NOT NULL,
        dest_path TEXT,
        is_directory INTEGER NOT NULL DEFAULT 0,
        file_size INTEGER,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
    );
    
    CREATE INDEX IF NOT EXISTS idx_timestamp ON file_events(timestamp);
    CREATE INDEX IF NOT EXISTS idx_event_type ON file_events(event_type);
    CREATE INDEX IF NOT EXISTS idx_src_path ON file_events(src_path);
    """
    
    def __init__(self, db_path: Path):
        self.db_path = db_path
        self._ensure_db_directory()
        self._init_schema()
    
    def _ensure_db_directory(self) -> None:
        """Ensure the database directory exists."""
        try:
            self.db_path.parent.mkdir(parents=True, exist_ok=True)
        except OSError as e:
            logging.error(f"Failed to create database directory: {e}")
            raise
    
    def _init_schema(self) -> None:
        """Initialize the database schema."""
        try:
            with self._get_connection() as conn:
                conn.executescript(self.SCHEMA)
                conn.commit()
        except sqlite3.Error as e:
            logging.error(f"Failed to initialize database schema: {e}")
            raise
    
    @contextmanager
    def _get_connection(self):
        """Context manager for database connections."""
        conn = None
        try:
            conn = sqlite3.connect(self.db_path, timeout=30.0)
            conn.row_factory = sqlite3.Row
            yield conn
        except sqlite3.Error as e:
            logging.error(f"Database error: {e}")
            raise
        finally:
            if conn:
                conn.close()
    
    def insert_event(self, event: FileEvent) -> Optional[int]:
        """Insert a file event into the database. Returns the event ID."""
        query = """
        INSERT INTO file_events (timestamp, event_type, src_path, dest_path, is_directory, file_size)
        VALUES (?, ?, ?, ?, ?, ?)
        """
        try:
            with self._get_connection() as conn:
                cursor = conn.execute(query, (
                    event.timestamp.isoformat(),
                    event.event_type,
                    event.src_path,
                    event.dest_path,
                    1 if event.is_directory else 0,
                    event.file_size
                ))
                conn.commit()
                return cursor.lastrowid
        except sqlite3.Error as e:
            logging.error(f"Failed to insert event: {e}")
            return None
    
    def get_stats(self) -> dict:
        """Get database statistics."""
        try:
            with self._get_connection() as conn:
                cursor = conn.execute("SELECT COUNT(*) as total FROM file_events")
                total = cursor.fetchone()["total"]
                
                cursor = conn.execute("""
                    SELECT event_type, COUNT(*) as count 
                    FROM file_events 
                    GROUP BY event_type
                """)
                by_type = {row["event_type"]: row["count"] for row in cursor.fetchall()}
                
                return {"total_events": total, "events_by_type": by_type}
        except sqlite3.Error as e:
            logging.error(f"Failed to get stats: {e}")
            return {"total_events": 0, "events_by_type": {}}
    
    def get_recent_events(self, limit: int = 10) -> list:
        """Get recent events from the database."""
        try:
            with self._get_connection() as conn:
                cursor = conn.execute("""
                    SELECT * FROM file_events 
                    ORDER BY timestamp DESC 
                    LIMIT ?
                """, (limit,))
                return [dict(row) for row in cursor.fetchall()]
        except sqlite3.Error as e:
            logging.error(f"Failed to get recent events: {e}")
            return []


# =============================================================================
# File System Event Handler
# =============================================================================

class FileEventHandler(FileSystemEventHandler):
    """Handles file system events and logs them to the database."""
    
    def __init__(self, db_manager: DatabaseManager):
        self.db_manager = db_manager
        self._supported_events = {
            'created', 'modified', 'moved', 'deleted'
        }
    
    def _get_file_size(self, path: str) -> Optional[int]:
        """Get file size in bytes, or None if unavailable."""
        try:
            if os.path.isfile(path):
                return os.path.getsize(path)
        except (OSError, IOError) as e:
            logging.debug(f"Could not get file size for {path}: {e}")
        return None
    
    def _create_event(self, event_type: str, event: FileSystemEvent) -> FileEvent:
        """Create a FileEvent from a watchdog event."""
        dest_path = None
        if hasattr(event, 'dest_path') and event.dest_path:
            dest_path = event.dest_path
        
        file_size = None
        if event_type in ('created', 'modified') and not event.is_directory:
            file_size = self._get_file_size(event.src_path)
        
        return FileEvent(
            timestamp=datetime.now(),
            event_type=event_type,
            src_path=event.src_path,
            dest_path=dest_path,
            is_directory=event.is_directory,
            file_size=file_size
        )
    
    def _log_event(self, event_type: str, event: FileSystemEvent) -> None:
        """Log an event to the database."""
        file_event = self._create_event(event_type, event)
        
        event_id = self.db_manager.insert_event(file_event)
        
        if event_id:
            item_type = "directory" if event.is_directory else "file"
            if event_type == 'moved':
                logging.info(f"[{event_type.upper()}] {item_type}: {event.src_path} -> {event.dest_path} (ID: {event_id})")
            else:
                logging.info(f"[{event_type.upper()}] {item_type}: {event.src_path} (ID: {event_id})")
        else:
            logging.warning(f"Failed to log event: {event_type} - {event.src_path}")
    
    def on_created(self, event: FileSystemEvent) -> None:
        self._log_event('created', event)
    
    def on_modified(self, event: FileSystemEvent) -> None:
        self._log_event('modified', event)
    
    def on_moved(self, event: FileSystemEvent) -> None:
        self._log_event('moved', event)
    
    def on_deleted(self, event: FileSystemEvent) -> None:
        self._log_event('deleted', event)


# =============================================================================
# Directory Monitor
# =============================================================================

class DirectoryMonitor:
    """Main class for monitoring directories."""
    
    def __init__(
        self,
        watch_path: Path,
        db_path: Path,
        recursive: bool = True,
        patterns: Optional[list] = None,
        ignore_patterns: Optional[list] = None
    ):
        self.watch_path = watch_path.resolve()
        self.db_manager = DatabaseManager(db_path)
        self.recursive = recursive
        self.patterns = patterns
        self.ignore_patterns = ignore_patterns
        self.observer: Optional[Observer] = None
        self._running = False
    
    def _validate_path(self) -> None:
        """Validate the watch path."""
        if not self.watch_path.exists():
            raise FileNotFoundError(f"Watch path does not exist: {self.watch_path}")
        
        if not self.watch_path.is_dir():
            raise NotADirectoryError(f"Watch path is not a directory: {self.watch_path}")
        
        if not os.access(self.watch_path, os.R_OK):
            raise PermissionError(f"No read permission for: {self.watch_path}")
    
    def start(self) -> None:
        """Start monitoring the directory."""
        self._validate_path()
        
        logging.info(f"Starting directory monitor...")
        logging.info(f"Watching: {self.watch_path}")
        logging.info(f"Database: {self.db_manager.db_path}")
        logging.info(f"Recursive: {self.recursive}")
        
        event_handler = FileEventHandler(self.db_manager)
        self.observer = Observer()
        
        watch = self.observer.schedule(
            event_handler,
            str(self.watch_path),
            recursive=self.recursive
        )
        
        self.observer.start()
        self._running = True
        
        logging.info("Monitor started. Press Ctrl+C to stop.")
        
        try:
            while self._running:
                time.sleep(1)
        except KeyboardInterrupt:
            logging.info("\nReceived stop signal")
        finally:
            self.stop()
    
    def stop(self) -> None:
        """Stop the monitor gracefully."""
        if self.observer:
            logging.info("Stopping observer...")
            self.observer.stop()
            self.observer.join()
            self.observer = None
        
        self._running = False
        logging.info("Monitor stopped")
        
        # Print final stats
        stats = self.db_manager.get_stats()
        logging.info(f"Total events logged: {stats['total_events']}")


# =============================================================================
# CLI Interface
# =============================================================================

def setup_logging(log_level: str, log_file: Optional[Path] = None) -> None:
    """Configure logging."""
    log_format = "%(asctime)s [%(levelname)s] %(message)s"
    date_format = "%Y-%m-%d %H:%M:%S"
    
    handlers = [logging.StreamHandler(sys.stdout)]
    
    if log_file:
        log_file.parent.mkdir(parents=True, exist_ok=True)
        handlers.append(logging.FileHandler(log_file, mode='a'))
    
    logging.basicConfig(
        level=getattr(logging, log_level.upper()),
        format=log_format,
        datefmt=date_format,
        handlers=handlers
    )


def parse_args() -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(
        description="Monitor a directory for file changes and log to SQLite.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s /path/to/watch
  %(prog)s /path/to/watch --db-path /custom/path.db --log-level DEBUG
  %(prog)s /path/to/watch --no-recursive --ignore-pattern "*.tmp"
        """
    )
    
    parser.add_argument(
        "path",
        type=Path,
        help="Directory path to monitor"
    )
    
    parser.add_argument(
        "--db-path",
        type=Path,
        default=DEFAULT_DB_PATH,
        help=f"Path to SQLite database (default: {DEFAULT_DB_PATH})"
    )
    
    parser.add_argument(
        "--log-file",
        type=Path,
        default=None,
        help="Path to log file (default: stdout only)"
    )
    
    parser.add_argument(
        "--log-level",
        choices=['DEBUG', 'INFO', 'WARNING', 'ERROR'],
        default='INFO',
        help="Logging level (default: INFO)"
    )
    
    parser.add_argument(
        "--no-recursive",
        action="store_true",
        help="Don't watch subdirectories"
    )
    
    parser.add_argument(
        "--pattern",
        action="append",
        help="Pattern to match (can be specified multiple times)"
    )
    
    parser.add_argument(
        "--ignore-pattern",
        action="append",
        help="Pattern to ignore (can be specified multiple times)"
    )
    
    parser.add_argument(
        "--stats",
        action="store_true",
        help="Show database statistics and exit"
    )
    
    parser.add_argument(
        "--recent",
        type=int,
        metavar='N',
        help="Show N recent events and exit"
    )
    
    return parser.parse_args()


def main() -> int:
    """Main entry point."""
    args = parse_args()
    
    setup_logging(args.log_level, args.log_file)
    
    # Handle --stats and --recent options
    if args.stats or args.recent:
        db = DatabaseManager(args.db_path)
        
        if args.stats:
            stats = db.get_stats()
            print(f"\nDatabase: {args.db_path}")
            print(f"Total events: {stats['total_events']}")
            print("\nEvents by type:")
            for event_type, count in sorted(stats['events_by_type'].items()):
                print(f"  {event_type}: {count}")
        
        if args.recent:
            events = db.get_recent_events(args.recent)
            print(f"\nRecent {len(events)} events:")
            print("-" * 80)
            for event in events:
                print(f"ID: {event['id']} | {event['timestamp']} | {event['event_type']:8} | {event['src_path']}")
        
        return 0
    
    # Start monitoring
    try:
        monitor = DirectoryMonitor(
            watch_path=args.path,
            db_path=args.db_path,
            recursive=not args.no_recursive,
            patterns=args.pattern,
            ignore_patterns=args.ignore_pattern
        )
        monitor.start()
        return 0
    
    except FileNotFoundError as e:
        logging.error(f"Error: {e}")
        return 1
    except PermissionError as e:
        logging.error(f"Error: {e}")
        return 1
    except KeyboardInterrupt:
        logging.info("Exiting...")
        return 0
    except Exception as e:
        logging.error(f"Unexpected error: {e}")
        logging.debug("Exception details:", exc_info=True)
        return 1


if __name__ == "__main__":
    sys.exit(main())
