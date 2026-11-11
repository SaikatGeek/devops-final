"""Order status updates in PostgreSQL.

Every update is guarded by the current status, so a duplicate or replayed queue
message can never move an order backwards (e.g. COMPLETED -> PROCESSING).
"""

import asyncio
from typing import Any

import asyncpg

from .config import Settings


class OrderStore:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._pool: asyncpg.Pool | None = None
        self._lock = asyncio.Lock()

    async def _get_pool(self) -> asyncpg.Pool:
        if self._pool is None:
            async with self._lock:
                if self._pool is None:
                    s = self._settings
                    self._pool = await asyncpg.create_pool(
                        host=s.postgres_host,
                        port=s.postgres_port,
                        database=s.postgres_db,
                        user=s.postgres_user,
                        password=s.postgres_password,
                        min_size=1,
                        max_size=max(2, s.concurrency),
                        timeout=3,
                        command_timeout=10,
                    )
        return self._pool

    async def close(self) -> None:
        if self._pool is not None:
            await self._pool.close()
            self._pool = None

    async def start_processing(self, order_id: int) -> dict[str, Any] | None:
        """PENDING -> PROCESSING. None if the order is missing or not PENDING anymore."""
        pool = await self._get_pool()
        row = await pool.fetchrow(
            """
            UPDATE orders SET status = 'PROCESSING'
            WHERE id = $1 AND status = 'PENDING'
            RETURNING id, product_id, quantity
            """,
            order_id,
        )
        return dict(row) if row else None

    async def complete(self, order_id: int) -> None:
        """PROCESSING -> COMPLETED."""
        pool = await self._get_pool()
        await pool.execute(
            """
            UPDATE orders SET status = 'COMPLETED', completed_at = now()
            WHERE id = $1 AND status = 'PROCESSING'
            """,
            order_id,
        )

    async def fail(self, order_id: int) -> None:
        """PENDING or PROCESSING -> FAILED."""
        pool = await self._get_pool()
        await pool.execute(
            """
            UPDATE orders SET status = 'FAILED', completed_at = now()
            WHERE id = $1 AND status IN ('PENDING', 'PROCESSING')
            """,
            order_id,
        )
