"""Structured logging setup for PokeTeamDex backend.

Three sinks:
  • stdout   — JSON lines (Docker/Loki compatible)
  • file     — rotating file (LOG_DIR env var, default ./logs)
  • server   — background thread POSTing batches to UtilityBillsServer /logs/device

Call setup_logging() once at import time, then set_logs_token() after the
service-account login completes so subsequent log pushes include the
Authorization header.
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

# Module-level reference so main.py can update the token after startup auth.
_server_handler: "_ServerHandler | None" = None

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
        self._url = f"{logs_api_base_url.rstrip('/')}/logs/device?app_name=poketeamdex_api"
        self._token: str | None = None
        self._queue: queue.Queue[logging.LogRecord] = queue.Queue(maxsize=500)
        self._thread = threading.Thread(target=self._worker, daemon=True, name="log-flusher")
        self._thread.start()

    def set_token(self, token: str) -> None:
        self._token = token

    def get_token(self) -> str | None:
        return self._token

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
            headers: dict[str, str] = {
                "Content-Type": "application/json",
                "x-device-id": _DEVICE_ID,
                "x-level": records[-1].levelname,
            }
            if self._token:
                headers["authorization"] = f"Bearer {self._token}"
            req = urllib.request.Request(self._url, data=data, headers=headers)
            urllib.request.urlopen(req, timeout=5)
        except Exception:
            pass  # Drop silently — never block the app over logging failures

    @staticmethod
    def _format_record(record: logging.LogRecord) -> str:
        ts = datetime.fromtimestamp(record.created, tz=timezone.utc).isoformat()
        level = record.levelname.ljust(5)
        return f"[{ts}] [{level}] [{record.name}] {record.getMessage()}"


# ---------------------------------------------------------------------------
# Public helpers
# ---------------------------------------------------------------------------

def set_logs_token(token: str) -> None:
    """Wire in the UtilityBillsServer session token after startup auth."""
    if _server_handler is not None:
        _server_handler.set_token(token)


def get_logs_token() -> str | None:
    """Return the cached UtilityBillsServer token (None if not yet authed)."""
    return _server_handler.get_token() if _server_handler is not None else None


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

def setup_logging(logs_api_base_url: str) -> None:
    """Configure root logger with stdout, rotating file, and HTTP sinks."""
    global _server_handler

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
    _server_handler = _ServerHandler(logs_api_base_url)
    _server_handler.setFormatter(_PlainFormatter())
    root.addHandler(_server_handler)

    # Quiet noisy third-party loggers
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
    logging.getLogger("sqlalchemy.engine").setLevel(logging.WARNING)
