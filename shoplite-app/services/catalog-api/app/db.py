"""PostgreSQL access through an asyncpg connection pool.

The pool is created lazily on first use, so the API process starts even when the
database is not up yet; /readyz reports 503 until the database becomes reachable.
"""

import asyncio
from typing import Any

import asyncpg

from .config import Settings

# products.id is a PostgreSQL INTEGER (int4); larger values cannot exist.
INT4_MAX = 2_147_483_647


class Database:
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
                        max_size=10,
                        timeout=3,  # seconds to open a connection
                        command_timeout=5,  # seconds per query
                    )
        return self._pool

    async def close(self) -> None:
        if self._pool is not None:
            await self._pool.close()
            self._pool = None

    async def ping(self) -> None:
        pool = await self._get_pool()
        await pool.fetchval("SELECT 1")

    async def list_products(self) -> list[dict[str, Any]]:
        pool = await self._get_pool()
        rows = await pool.fetch("SELECT id, name, price, stock FROM products ORDER BY id")
        return [dict(row) for row in rows]

    async def get_product(self, product_id: int) -> dict[str, Any] | None:
        if not 1 <= product_id <= INT4_MAX:
            return None
        pool = await self._get_pool()
        row = await pool.fetchrow(
            "SELECT id, name, price, stock FROM products WHERE id = $1", product_id
        )
        return dict(row) if row else None
