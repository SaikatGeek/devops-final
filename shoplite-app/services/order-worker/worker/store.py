"""Order status updates in PostgreSQL.

Every update is guarded by the current status, so a duplicate or replayed queue
message can never move an order backwards (e.g. COMPLETED -> PROCESSING).
Each query runs in a CLIENT span, the "database" hop of the order's trace.
"""

import asyncio
from typing import Any

import asyncpg
from opentelemetry import trace
from opentelemetry.trace import SpanKind

from .config import Settings

tracer = trace.get_tracer("shoplite.order-worker.db")


class OrderStore:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._pool: asyncpg.Pool | None = None
        self._lock = asyncio.Lock()

    def _span(self, statement: str):
        s = self._settings
        return tracer.start_as_current_span(
            "UPDATE orders",
            kind=SpanKind.CLIENT,
            attributes={
                "db.system": "postgresql",
                "db.system.name": "postgresql",
                "db.namespace": s.postgres_db,
                "db.operation.name": "UPDATE",
                "db.collection.name": "orders",
                "db.query.text": " ".join(statement.split()),
                "server.address": s.postgres_host,
                "server.port": s.postgres_port,
            },
        )

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
        sql = """
            UPDATE orders SET status = 'PROCESSING'
            WHERE id = $1 AND status = 'PENDING'
            RETURNING id, product_id, quantity
            """
        pool = await self._get_pool()
        with self._span(sql):
            row = await pool.fetchrow(sql, order_id)
        return dict(row) if row else None

    async def complete(self, order_id: int) -> None:
        """PROCESSING -> COMPLETED."""
        sql = """
            UPDATE orders SET status = 'COMPLETED', completed_at = now()
            WHERE id = $1 AND status = 'PROCESSING'
            """
        pool = await self._get_pool()
        with self._span(sql):
            await pool.execute(sql, order_id)

    async def fail(self, order_id: int) -> None:
        """PENDING or PROCESSING -> FAILED."""
        sql = """
            UPDATE orders SET status = 'FAILED', completed_at = now()
            WHERE id = $1 AND status IN ('PENDING', 'PROCESSING')
            """
        pool = await self._get_pool()
        with self._span(sql):
            await pool.execute(sql, order_id)
