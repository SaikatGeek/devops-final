"""Test fixtures: the API runs against in-memory fakes, no PostgreSQL or Redis needed."""

from datetime import datetime, timezone

import pytest
from fastapi.testclient import TestClient
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import SimpleSpanProcessor
from opentelemetry.sdk.trace.export.in_memory_span_exporter import InMemorySpanExporter

from app.config import Settings
from app.main import create_app

# One real tracer provider for the whole test session (the global provider can be
# set only once). Spans go to memory so tests can inspect them.
SPANS = InMemorySpanExporter()
_provider = TracerProvider()
_provider.add_span_processor(SimpleSpanProcessor(SPANS))
trace.set_tracer_provider(_provider)

PRODUCTS = [
    {"id": 1, "name": "Wireless Mouse", "price": 19.99, "stock": 120},
    {"id": 2, "name": "Mechanical Keyboard", "price": 79.50, "stock": 60},
]


class FakeDatabase:
    def __init__(self) -> None:
        self.products = {p["id"]: dict(p) for p in PRODUCTS}
        self.orders: dict[int, dict] = {}
        self.healthy = True
        self.closed = False

    async def ping(self) -> None:
        if not self.healthy:
            raise ConnectionError("database down")

    async def list_products(self) -> list[dict]:
        return list(self.products.values())

    async def get_product(self, product_id: int) -> dict | None:
        return self.products.get(product_id)

    async def create_order(self, product_id: int, quantity: int) -> dict | None:
        if product_id not in self.products:
            return None
        order = {
            "id": len(self.orders) + 1,
            "product_id": product_id,
            "quantity": quantity,
            "status": "PENDING",
            "created_at": datetime.now(timezone.utc),
            "completed_at": None,
        }
        self.orders[order["id"]] = order
        return dict(order)

    async def get_order(self, order_id: int) -> dict | None:
        order = self.orders.get(order_id)
        return dict(order) if order else None

    async def mark_order_failed(self, order_id: int) -> None:
        self.orders[order_id]["status"] = "FAILED"
        self.orders[order_id]["completed_at"] = datetime.now(timezone.utc)

    async def close(self) -> None:
        self.closed = True


class FakeQueue:
    def __init__(self) -> None:
        self.messages: list[str] = []  # raw JSON messages, as Redis would hold them
        self.healthy = True
        self.closed = False

    async def ping(self) -> None:
        if not self.healthy:
            raise ConnectionError("redis down")

    async def enqueue(self, message: str) -> None:
        if not self.healthy:
            raise ConnectionError("redis down")
        self.messages.append(message)

    async def depth(self) -> int:
        if not self.healthy:
            raise ConnectionError("redis down")
        return len(self.messages)

    async def close(self) -> None:
        self.closed = True


@pytest.fixture
def db() -> FakeDatabase:
    return FakeDatabase()


@pytest.fixture
def queue() -> FakeQueue:
    return FakeQueue()


@pytest.fixture
def spans() -> InMemorySpanExporter:
    SPANS.clear()
    return SPANS


@pytest.fixture
def client(db: FakeDatabase, queue: FakeQueue):
    app = create_app(Settings(postgres_password="unused"), db=db, queue=queue)
    with TestClient(app) as test_client:  # `with` runs the lifespan startup/shutdown
        yield test_client
