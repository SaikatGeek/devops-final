"""Processes one queue message: PENDING -> PROCESSING -> (1-2 s of work) -> COMPLETED.

The message carries the API's trace context (`traceparent`). The worker continues
that trace with a CONSUMER span, so one order is one trace:
API request -> queue send -> worker process -> database updates.

`handle` never raises: a bad message or a failed order is logged and the
consumer loop moves on to the next message.
"""

import asyncio
import hashlib
import json
import logging
import random
import time
from datetime import datetime, timezone
from typing import Any, Protocol

from opentelemetry import propagate, trace
from opentelemetry.trace import SpanKind, Status, StatusCode

from .metrics import ORDER_PROCESSING, ORDERS_PROCESSED, exemplar

log = logging.getLogger("shoplite.worker")
tracer = trace.get_tracer("shoplite.order-worker")

PENDING_QUEUE = "orders:pending"

# CHAOS_MEMORY_LEAK: memory kept for every processed order and never freed. About 1 MB
# per order makes the pod's memory climb steadily until it is OOMKilled.
RETAINED_BYTES_PER_ORDER = 1024 * 1024


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


def parse_message(raw: str) -> dict[str, Any] | None:
    """Decoded message, or None unless it is a JSON object with a positive int order_id."""
    try:
        message = json.loads(raw)
    except ValueError:
        return None
    if not isinstance(message, dict):
        return None
    order_id = message.get("order_id")
    return message if isinstance(order_id, int) and order_id > 0 else None


def queue_wait_ms(message: dict[str, Any]) -> float | None:
    """How long the message sat in the queue, from the API's enqueued_at timestamp."""
    try:
        enqueued = datetime.fromisoformat(message["enqueued_at"])
    except (KeyError, TypeError, ValueError):
        return None
    waited = (datetime.now(timezone.utc) - enqueued).total_seconds() * 1000
    return round(max(waited, 0.0), 1)  # clocks of API and worker pods may differ slightly


class OrderProcessor:
    def __init__(
        self,
        store: Store,
        min_seconds: float = 1.0,
        max_seconds: float = 2.0,
        cpu_seconds: float = 0.2,
        memory_leak: bool = False,
    ) -> None:
        self.store = store
        self.min_seconds = min_seconds
        self.max_seconds = max_seconds
        self.cpu_seconds = cpu_seconds
        self.memory_leak = memory_leak
        self.retained: list[bytes] = []  # grows only while memory_leak is on

    async def simulate_work(self) -> None:
        total = random.uniform(self.min_seconds, self.max_seconds)
        cpu = min(self.cpu_seconds, total)
        with tracer.start_as_current_span(
            "simulate work", attributes={"shoplite.work_seconds": round(total, 3)}
        ):
            if cpu > 0:
                # In a thread, so the event loop keeps serving the other consumers and /healthz.
                await asyncio.to_thread(burn_cpu, cpu)
            await asyncio.sleep(total - cpu)

    async def handle(self, raw: str) -> str:
        """Process one message; returns the outcome: completed, failed, skipped or invalid."""
        start = time.perf_counter()
        message = parse_message(raw)
        # Continue the API's trace when the message carries a traceparent.
        parent = propagate.extract(message) if message else None

        with tracer.start_as_current_span(
            f"process {PENDING_QUEUE}",
            context=parent,
            kind=SpanKind.CONSUMER,
            attributes={
                "messaging.system": "redis",
                "messaging.destination.name": PENDING_QUEUE,
                "messaging.operation.type": "process",
            },
        ) as span:
            if message is None:
                log.error("invalid queue message dropped", extra={"raw_message": raw[:200]})
                span.set_status(Status(StatusCode.ERROR, "invalid message"))
                result = "invalid"
            else:
                span.set_attribute("shoplite.order_id", message["order_id"])
                wait = queue_wait_ms(message)
                if wait is not None:
                    span.set_attribute("shoplite.queue_wait_ms", wait)
                result = await self._process(message["order_id"], span)
            span.set_attribute("shoplite.result", result)

            # Inside the span, so the latency exemplar points at this order's trace.
            ORDERS_PROCESSED.labels(result=result).inc()
            if result in ("completed", "failed"):
                ORDER_PROCESSING.observe(time.perf_counter() - start, exemplar=exemplar())
                if self.memory_leak:
                    # Non-zero bytes: the pages are really written, so they count in the pod's memory.
                    self.retained.append(b"\xff" * RETAINED_BYTES_PER_ORDER)
        return result

    async def _process(self, order_id: int, span: trace.Span) -> str:
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
        except Exception as exc:
            log.exception("order processing failed", extra={"order_id": order_id})
            span.record_exception(exc)
            span.set_status(Status(StatusCode.ERROR, type(exc).__name__))
            try:
                await self.store.fail(order_id)
            except Exception:
                log.exception("could not mark order failed", extra={"order_id": order_id})
            return "failed"
