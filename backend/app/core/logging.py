"""Structured logging setup for PokeTeamDex backend.

Three sinks:
  • stdout   — JSON lines (Docker/Loki compatible)
  • file     — rotating file (LOG_DIR env var, default ./logs)
  • server   — background thread POSTing batches to UtilityBillsServer /logs/device
"""

import json
import logging
import logging.handlers
import os
import queue
import threading
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

_DEVICE_ID = "poketeamdex-backend"

# ---------------------------------------------------------------------------
# Formatters
# ---------------------------------------------------------------------------

class _JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        entry: dict = {
            "ts": datetime.fromtimestamp(record.created, tz=timezone.utc).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "msg": record.getMessage(),
        }
        if record.exc_info:
            entry["exc"] = self.formatException(record.exc_info)
        return json.dumps(entry)


class _PlainFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        ts = datetime.fromtimestamp(record.created, tz=timezone.utc).strftime(
            "%Y-%m-%dT%H:%M:%SZ"
        )
        level = record.levelname.ljust(5)
        base = f"[{ts}] [{level}] [{record.name}] {record.getMessage()}"
        if record.exc_info:
            base += "\n" + self.formatException(record.exc_info)
        return base


# ---------------------------------------------------------------------------
# UtilityBillsServer HTTP handler (background thread, non-blocking)
# ---------------------------------------------------------------------------

class _ServerHandler(logging.Handler):
    """Buffers log lines and flushes every 3s or 20 records to /logs/device."""

    BATCH_SIZE = 20
    FLUSH_INTERVAL = 3  # seconds

    def __init__(self, logs_api_base_url: str) -> None:
        super().__init__()
        self._url = f"{logs_api_base_url.rstrip('/')}/logs/device"
        self._queue: queue.Queue[logging.LogRecord] = queue.Queue(maxsize=500)
        self._thread = threading.Thread(target=self._worker, daemon=True, name="log-flusher")
        self._thread.start()

    def emit(self, record: logging.LogRecord) -> None:
        try:
            self._queue.put_nowait(record)
        except queue.Full:
            pass

    def _worker(self) -> None:
        buf: list[logging.LogRecord] = []
        while True:
            try:
                record = self._queue.get(timeout=self.FLUSH_INTERVAL)
                buf.append(record)
                # Drain any immediately available records up to batch size.
                while len(buf) < self.BATCH_SIZE:
                    try:
                        buf.append(self._queue.get_nowait())
                    except queue.Empty:
                        break
                self._send(buf)
                buf.clear()
            except queue.Empty:
                if buf:
                    self._send(buf)
                    buf.clear()

    def _send(self, records: list[logging.LogRecord]) -> None:
        lines = [self._format_record(r) for r in records]
        try:
            data = json.dumps(lines).encode()
            req = urllib.request.Request(
                self._url,
                data=data,
                headers={
                    "Content-Type": "application/json",
                    "x-device-id": _DEVICE_ID,
                    "x-level": records[-1].levelname,
                },
            )
            urllib.request.urlopen(req, timeout=5)
        except Exception:
            pass  # Drop silently — never block the app over logging failures

    @staticmethod
    def _format_record(record: logging.LogRecord) -> str:
        ts = datetime.fromtimestamp(record.created, tz=timezone.utc).isoformat()
        level = record.levelname.ljust(5)
        return f"[{ts}] [{level}] [{record.name}] {record.getMessage()}"


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

def setup_logging(logs_api_base_url: str) -> None:
    """Configure root logger with stdout, rotating file, and HTTP sinks."""
    root = logging.getLogger()
    root.setLevel(logging.INFO)

    # Stdout — JSON for Docker/Loki ingestion
    stdout_handler = logging.StreamHandler()
    stdout_handler.setFormatter(_JsonFormatter())
    root.addHandler(stdout_handler)

    # Rotating file
    log_dir = Path(os.getenv("LOG_DIR", "./logs"))
    log_dir.mkdir(parents=True, exist_ok=True)
    file_handler = logging.handlers.RotatingFileHandler(
        log_dir / "poketeamdex-backend.log",
        maxBytes=10 * 1024 * 1024,  # 10 MB
        backupCount=5,
        encoding="utf-8",
    )
    file_handler.setFormatter(_PlainFormatter())
    root.addHandler(file_handler)

    # UtilityBillsServer HTTP push
    server_handler = _ServerHandler(logs_api_base_url)
    server_handler.setFormatter(_PlainFormatter())
    root.addHandler(server_handler)

    # Quiet noisy third-party loggers
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
    logging.getLogger("sqlalchemy.engine").setLevel(logging.WARNING)
