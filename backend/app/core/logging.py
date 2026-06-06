"""Structured logging setup for PokeTeamDex backend.

Three sinks:
  • stdout — JSON lines (Docker/Loki compatible)
  • file   — rotating file (LOG_DIR env var, default ./logs)
  • loki   — background thread pushing batches directly to Loki /loki/api/v1/push
"""

import logging
import logging.handlers
import os
import queue
import threading
from datetime import datetime, timezone
from pathlib import Path

from app.core.loki import push_sync


# ---------------------------------------------------------------------------
# Formatters
# ---------------------------------------------------------------------------

class _JsonFormatter(logging.Formatter):
    import json as _json

    def format(self, record: logging.LogRecord) -> str:
        import json
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
# Loki handler (background thread, non-blocking)
# ---------------------------------------------------------------------------

class _LokiHandler(logging.Handler):
    """Buffers server log records and flushes directly to Loki every 3s or 20 records."""

    BATCH_SIZE = 20
    FLUSH_INTERVAL = 3  # seconds

    _BASE_LABELS = {"job": "server", "source": "direct", "app": "poketeamdex_api"}

    def __init__(self, loki_url: str) -> None:
        super().__init__()
        self._loki_url = loki_url
        self._queue: queue.Queue[logging.LogRecord] = queue.Queue(maxsize=500)
        self._thread = threading.Thread(target=self._worker, daemon=True, name="loki-flusher")
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
                while len(buf) < self.BATCH_SIZE:
                    try:
                        buf.append(self._queue.get_nowait())
                    except queue.Empty:
                        break
                self._flush(buf)
                buf.clear()
            except queue.Empty:
                if buf:
                    self._flush(buf)
                    buf.clear()

    def _flush(self, records: list[logging.LogRecord]) -> None:
        labels = {**self._BASE_LABELS, "level": records[-1].levelname}
        lines = [self._fmt(r) for r in records]
        push_sync(self._loki_url, labels, lines)

    @staticmethod
    def _fmt(record: logging.LogRecord) -> str:
        ts = datetime.fromtimestamp(record.created, tz=timezone.utc).isoformat()
        level = record.levelname.ljust(5)
        return f"[{ts}] [{level}] [{record.name}] {record.getMessage()}"


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

def setup_logging(loki_url: str) -> None:
    """Configure root logger with stdout, rotating file, and Loki sinks."""
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

    # Direct Loki push
    root.addHandler(_LokiHandler(loki_url))

    # Quiet noisy third-party loggers
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
    logging.getLogger("sqlalchemy.engine").setLevel(logging.WARNING)
