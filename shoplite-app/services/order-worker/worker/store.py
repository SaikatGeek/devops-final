"""Order status updates in PostgreSQL.

Every update is guarded by the current status, so a duplicate or replayed queue
message can never move an order backwards (e.g. COMPLETED -> PROCESSING).
Each query runs in a CLIENT span, the "database" hop of the order's trace.

With CHAOS_SLOW_DB on, `SELECT pg_sleep(2)` runs before every update. It gets an
ordinary DB span, so the trace shows a 2-second query in front of each UPDATE.
"""

import asyncio
from typing import Any

import asyncpg
from opentelemetry import trace
from opentelemetry.trace import SpanKind

from .config import Settings

tracer = trace.get_tracer("shoplite.order-worker.db")

SLEEP_SQL = "SELECT pg_sleep(2)"


class OrderStore:
    def __init__(self, settings: Settings, pool: asyncpg.Pool | None = None) -> None:
        self._settings = settings
        self._pool = pool  # tests pass a fake; normally created on first use
        self._lock = asyncio.Lock()

    def _span(self, operation: str, statement: str, table: str | None = "orders"):
        s = self._settings
        attributes = {
            "db.system": "postgresql",
            "db.system.name": "postgresql",
            "db.namespace": s.postgres_db,
            "db.operation.name": operation,
            "db.query.text": " ".join(statement.split()),
            "server.address": s.postgres_host,
            "server.port": s.postgres_port,
        }
        if table:
            attributes["db.collection.name"] = table
        return tracer.start_as_current_span(
            f"{operation} {table}" if table else operation,
            kind=SpanKind.CLIENT,
            attributes=attributes,
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

    async def _before_update(self, pool: asyncpg.Pool) -> None:
        # CHAOS_SLOW_DB: a 2-second query in front of every update.
        if self._settings.chaos_slow_db:
            with self._span("SELECT", SLEEP_SQL, table=None):
                await pool.execute(SLEEP_SQL)

    async def start_processing(self, order_id: int) -> dict[str, Any] | None:
        """PENDING -> PROCESSING. None if the order is missing or not PENDING anymore."""
        sql = """
            UPDATE orders SET status = 'PROCESSING'
            WHERE id = $1 AND status = 'PENDING'
            RETURNING id, product_id, quantity
            """
        pool = await self._get_pool()
        await self._before_update(pool)
        with self._span("UPDATE", sql):
            row = await pool.fetchrow(sql, order_id)
        return dict(row) if row else None

    async def complete(self, order_id: int) -> None:
        """PROCESSING -> COMPLETED."""
        sql = """
            UPDATE orders SET status = 'COMPLETED', completed_at = now()
            WHERE id = $1 AND status = 'PROCESSING'
            """
        pool = await self._get_pool()
        await self._before_update(pool)
        with self._span("UPDATE", sql):
            await pool.execute(sql, order_id)

    async def fail(self, order_id: int) -> None:
        """PENDING or PROCESSING -> FAILED."""
        sql = """
            UPDATE orders SET status = 'FAILED', completed_at = now()
            WHERE id = $1 AND status IN ('PENDING', 'PROCESSING')
            """
        pool = await self._get_pool()
        await self._before_update(pool)
        with self._span("UPDATE", sql):
            await pool.execute(sql, order_id)
