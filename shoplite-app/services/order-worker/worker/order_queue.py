"""Consumer side of the Redis list `orders:pending` (catalog-api LPUSHes, we BRPOP)."""

import redis.asyncio as redis

PENDING_QUEUE = "orders:pending"


class RedisConsumer:
    def __init__(self, url: str) -> None:
        self._client = redis.from_url(
            url,
            socket_connect_timeout=2,
            socket_timeout=10,  # must be longer than the BRPOP timeout below
            decode_responses=True,
        )

    async def pop(self, timeout: float = 1.0) -> str | None:
        """Block up to `timeout` seconds for one message; None if the queue stayed empty.

        A short timeout lets the consumer loop notice a shutdown request quickly.
        """
        result = await self._client.brpop([PENDING_QUEUE], timeout=timeout)
        return result[1] if result else None

    async def close(self) -> None:
        await self._client.aclose()
