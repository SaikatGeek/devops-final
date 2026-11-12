"""In-memory stand-ins for PostgreSQL and Redis."""

import asyncio
import json


class FakeStore:
    def __init__(self, orders: dict[int, str] | None = None) -> None:
        # order_id -> status
        self.status: dict[int, str] = dict(orders or {})
        self.fail_on_complete = False

    async def start_processing(self, order_id: int):
        if self.status.get(order_id) != "PENDING":
            return None
        self.status[order_id] = "PROCESSING"
        return {"id": order_id, "product_id": 1, "quantity": 1}

    async def complete(self, order_id: int) -> None:
        if self.fail_on_complete:
            raise ConnectionError("database down")
        if self.status.get(order_id) == "PROCESSING":
            self.status[order_id] = "COMPLETED"

    async def fail(self, order_id: int) -> None:
        if self.status.get(order_id) in ("PENDING", "PROCESSING"):
            self.status[order_id] = "FAILED"


class FakePool:
    """Stand-in for an asyncpg pool: records every statement, touches no database."""

    def __init__(self) -> None:
        self.statements: list[str] = []

    async def fetchrow(self, sql: str, *args):
        self.statements.append(" ".join(sql.split()))
        return {"id": args[0], "product_id": 1, "quantity": 1}

    async def execute(self, sql: str, *args) -> str:
        self.statements.append(" ".join(sql.split()))
        return "UPDATE 1"

    async def close(self) -> None:
        pass


class FakeConsumer:
    def __init__(self, order_ids: list[int] | None = None) -> None:
        self.messages = [json.dumps({"order_id": i}) for i in order_ids or []]
        self.closed = False

    async def pop(self, timeout: float = 1.0) -> str | None:
        if self.messages:
            return self.messages.pop(0)
        await asyncio.sleep(min(timeout, 0.01))
        return None

    async def close(self) -> None:
        self.closed = True


def message(order_id: int) -> str:
    return json.dumps({"order_id": order_id, "enqueued_at": "2026-11-12T00:00:00+00:00"})
