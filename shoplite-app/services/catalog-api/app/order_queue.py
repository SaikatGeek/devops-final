"""Order queue backed by the Redis list `orders:pending`.

The API pushes with LPUSH and order-worker pops with BRPOP, so the list behaves as
a FIFO queue. Each message is a small JSON object; the worker reads the order
details from PostgreSQL, so the database stays the single source of truth.

Trace context travels inside the message: `traceparent` (W3C Trace Context) is
written by the API's PRODUCER span and read by the worker, so API -> queue ->
worker -> database is one trace.
"""

import json
from datetime import datetime, timezone

import redis.asyncio as redis
from opentelemetry import propagate, trace
from opentelemetry.trace import SpanKind

PENDING_QUEUE = "orders:pending"

tracer = trace.get_tracer("shoplite.catalog-api.queue")


def publish_span(order_id: int):
    """PRODUCER span around pushing one order onto the queue."""
    return tracer.start_as_current_span(
        f"send {PENDING_QUEUE}",
        kind=SpanKind.PRODUCER,
        attributes={
            "messaging.system": "redis",
            "messaging.destination.name": PENDING_QUEUE,
            "messaging.operation.type": "send",
            "messaging.operation.name": "LPUSH",
            "shoplite.order_id": order_id,
        },
    )


def build_message(order_id: int) -> str:
    """JSON message for one order, carrying the current trace context."""
    message: dict[str, object] = {
        "order_id": order_id,
        "enqueued_at": datetime.now(timezone.utc).isoformat(),
    }
    carrier: dict[str, str] = {}
    propagate.inject(carrier)  # adds "traceparent" (and "tracestate" if any)
    message.update(carrier)
    return json.dumps(message)


class RedisQueue:
    def __init__(self, url: str) -> None:
        # redis-py connects lazily, so creating the client never fails.
        self._client = redis.from_url(
            url,
            socket_connect_timeout=2,
            socket_timeout=5,
            decode_responses=True,
        )

    async def ping(self) -> None:
        await self._client.ping()

    async def enqueue(self, message: str) -> None:
        await self._client.lpush(PENDING_QUEUE, message)

    async def depth(self) -> int:
        """Number of orders waiting; feeds the order_queue_depth gauge."""
        return await self._client.llen(PENDING_QUEUE)

    async def close(self) -> None:
        await self._client.aclose()
