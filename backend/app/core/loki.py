"""Minimal Loki push client used by both the logging handler and the /logs/device route."""

import json
import time
import urllib.request

import httpx


def push_sync(loki_url: str, labels: dict[str, str], lines: list[str]) -> None:
    """Synchronous push — used by the background logging thread."""
    if not lines:
        return
    now_ns = time.time_ns()
    values = [[str(now_ns + i), line] for i, line in enumerate(lines)]
    payload = json.dumps({"streams": [{"stream": labels, "values": values}]}).encode()
    try:
        req = urllib.request.Request(
            f"{loki_url.rstrip('/')}/loki/api/v1/push",
            data=payload,
            headers={"Content-Type": "application/json"},
        )
        urllib.request.urlopen(req, timeout=5)
    except Exception:
        pass  # Drop silently — never block the app over logging


async def push_async(loki_url: str, labels: dict[str, str], lines: list[str]) -> None:
    """Async push — used by the /logs/device route handler."""
    if not lines:
        return
    now_ns = time.time_ns()
    values = [[str(now_ns + i), line] for i, line in enumerate(lines)]
    try:
        async with httpx.AsyncClient(timeout=5) as client:
            await client.post(
                f"{loki_url.rstrip('/')}/loki/api/v1/push",
                json={"streams": [{"stream": labels, "values": values}]},
            )
    except Exception:
        pass  # Drop silently
