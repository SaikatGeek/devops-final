"""Processes one queue message: PENDING -> PROCESSING -> (1-2 s of work) -> COMPLETED.

`handle` never raises: a bad message or a failed order is logged and the
consumer loop moves on to the next message.
"""

import asyncio
import hashlib
import json
import logging
import random
import time
from typing import Any, Protocol

log = logging.getLogger("shoplite.worker")


class Store(Protocol):
    async def start_processing(self, order_id: int) -> dict[str, Any] | None: ...
    async def complete(self, order_id: int) -> None: ...
    async def fail(self, order_id: int) -> None: ...


def burn_cpu(seconds: float) -> None:
    """Busy-loop hashing for `seconds`, so processing shows up as real CPU usage."""
    deadline = time.perf_counter() + seconds
    digest = b"shoplite"
    while time.perf_counter() < deadline:
        digest = hashlib.sha256(digest).digest()


def parse_order_id(raw: str) -> int | None:
    try:
        order_id = json.loads(raw)["order_id"]
    except (ValueError, KeyError, TypeError):
        return None
    return order_id if isinstance(order_id, int) and order_id > 0 else None


class OrderProcessor:
    def __init__(
        self,
        store: Store,
        min_seconds: float = 1.0,
        max_seconds: float = 2.0,
        cpu_seconds: float = 0.2,
    ) -> None:
        self.store = store
        self.min_seconds = min_seconds
        self.max_seconds = max_seconds
        self.cpu_seconds = cpu_seconds

    async def simulate_work(self) -> None:
        total = random.uniform(self.min_seconds, self.max_seconds)
        cpu = min(self.cpu_seconds, total)
        if cpu > 0:
            # In a thread, so the event loop keeps serving the other consumers and /healthz.
            await asyncio.to_thread(burn_cpu, cpu)
        await asyncio.sleep(total - cpu)

    async def handle(self, raw: str) -> str:
        """Process one message; returns the outcome: completed, failed, skipped or invalid."""
        order_id = parse_order_id(raw)
        if order_id is None:
            log.error("invalid queue message dropped", extra={"raw_message": raw[:200]})
            return "invalid"

        start = time.perf_counter()
        try:
            order = await self.store.start_processing(order_id)
            if order is None:
                # Missing, or already handled (e.g. a duplicate message): nothing to do.
                log.warning("order not pending, skipped", extra={"order_id": order_id})
                return "skipped"

            log.info("order processing started", extra={"order_id": order_id})
            await self.simulate_work()
            await self.store.complete(order_id)
            log.info(
                "order completed",
                extra={"order_id": order_id, "duration_ms": round((time.perf_counter() - start) * 1000, 1)},
            )
            return "completed"
        except Exception:
            log.exception("order processing failed", extra={"order_id": order_id})
            try:
                await self.store.fail(order_id)
            except Exception:
                log.exception("could not mark order failed", extra={"order_id": order_id})
            return "failed"
