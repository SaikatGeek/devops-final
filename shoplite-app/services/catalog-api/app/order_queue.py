"""Order queue backed by the Redis list `orders:pending`.

The API pushes with LPUSH and order-worker pops with BRPOP, so the list behaves as
a FIFO queue. Each message is a small JSON object; the worker reads the order
details from PostgreSQL, so the database stays the single source of truth.
"""

import json
from datetime import datetime, timezone

import redis.asyncio as redis

PENDING_QUEUE = "orders:pending"


def build_message(order_id: int) -> str:
    return json.dumps(
        {
            "order_id": order_id,
            "enqueued_at": datetime.now(timezone.utc).isoformat(),
        }
    )


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

    async def enqueue(self, order_id: int) -> None:
        await self._client.lpush(PENDING_QUEUE, build_message(order_id))

    async def close(self) -> None:
        await self._client.aclose()
