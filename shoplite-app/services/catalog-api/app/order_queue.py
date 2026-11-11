"""Order queue backed by the Redis list `orders:pending`.

Step 2 only needs a reachability check for /readyz; enqueueing is added with POST /orders.
"""

import redis.asyncio as redis

PENDING_QUEUE = "orders:pending"


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

    async def close(self) -> None:
        await self._client.aclose()
