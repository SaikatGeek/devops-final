"""PostgreSQL access through an asyncpg connection pool.

The pool is created lazily on first use, so the API process starts even when the
database is not up yet; /readyz reports 503 until the database becomes reachable.

Every query runs inside a CLIENT span ("SELECT products", "INSERT orders", ...),
so a trace shows exactly which statement was slow or failed.
"""

import asyncio
from contextlib import nullcontext
from typing import Any

import asyncpg
from opentelemetry import trace
from opentelemetry.trace import SpanKind

from .config import Settings

# products.id is a PostgreSQL INTEGER (int4); larger values cannot exist.
INT4_MAX = 2_147_483_647

_ORDER_COLUMNS = "id, product_id, quantity, status, created_at, completed_at"

tracer = trace.get_tracer("shoplite.catalog-api.db")


class Database:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._pool: asyncpg.Pool | None = None
        self._lock = asyncio.Lock()

    def _span(self, operation: str, table: str, statement: str):
        """CLIENT span for one query, only inside an existing trace.

        Probe queries (/readyz) run outside any trace; they get no span, so they
        do not flood the tracing backend with one-span traces every few seconds.
        """
        if not trace.get_current_span().get_span_context().is_valid:
            return nullcontext()
        s = self._settings
        return tracer.start_as_current_span(
            f"{operation} {table}",
            kind=SpanKind.CLIENT,
            attributes={
                "db.system": "postgresql",
                "db.system.name": "postgresql",
                "db.namespace": s.postgres_db,
                "db.operation.name": operation,
                "db.collection.name": table,
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
        sql = "SELECT id, name, price, stock FROM products ORDER BY id"
        pool = await self._get_pool()
        with self._span("SELECT", "products", sql):
            rows = await pool.fetch(sql)
        return [dict(row) for row in rows]

    async def get_product(self, product_id: int) -> dict[str, Any] | None:
        if not 1 <= product_id <= INT4_MAX:
            return None
        sql = "SELECT id, name, price, stock FROM products WHERE id = $1"
        pool = await self._get_pool()
        with self._span("SELECT", "products", sql):
            row = await pool.fetchrow(sql, product_id)
        return dict(row) if row else None

    async def create_order(self, product_id: int, quantity: int) -> dict[str, Any] | None:
        """Insert a PENDING order; returns None when the product does not exist.

        INSERT ... SELECT inserts nothing when no product matches, so the existence
        check and the insert are one atomic statement.
        """
        sql = f"""
            INSERT INTO orders (product_id, quantity)
            SELECT id, $2 FROM products WHERE id = $1
            RETURNING {_ORDER_COLUMNS}
            """
        pool = await self._get_pool()
        with self._span("INSERT", "orders", sql):
            row = await pool.fetchrow(sql, product_id, quantity)
        return dict(row) if row else None

    async def get_order(self, order_id: int) -> dict[str, Any] | None:
        if not 1 <= order_id <= INT4_MAX:
            return None
        sql = f"SELECT {_ORDER_COLUMNS} FROM orders WHERE id = $1"
        pool = await self._get_pool()
        with self._span("SELECT", "orders", sql):
            row = await pool.fetchrow(sql, order_id)
        return dict(row) if row else None

    async def mark_order_failed(self, order_id: int) -> None:
        sql = "UPDATE orders SET status = 'FAILED', completed_at = now() WHERE id = $1"
        pool = await self._get_pool()
        with self._span("UPDATE", "orders", sql):
            await pool.execute(sql, order_id)
