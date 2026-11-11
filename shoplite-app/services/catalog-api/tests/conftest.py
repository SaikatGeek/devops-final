"""Test fixtures: the API runs against in-memory fakes, no PostgreSQL or Redis needed."""

import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app

PRODUCTS = [
    {"id": 1, "name": "Wireless Mouse", "price": 19.99, "stock": 120},
    {"id": 2, "name": "Mechanical Keyboard", "price": 79.50, "stock": 60},
]


class FakeDatabase:
    def __init__(self) -> None:
        self.products = {p["id"]: dict(p) for p in PRODUCTS}
        self.healthy = True
        self.closed = False

    async def ping(self) -> None:
        if not self.healthy:
            raise ConnectionError("database down")

    async def list_products(self) -> list[dict]:
        return list(self.products.values())

    async def get_product(self, product_id: int) -> dict | None:
        return self.products.get(product_id)

    async def close(self) -> None:
        self.closed = True


class FakeQueue:
    def __init__(self) -> None:
        self.healthy = True
        self.closed = False

    async def ping(self) -> None:
        if not self.healthy:
            raise ConnectionError("redis down")

    async def close(self) -> None:
        self.closed = True


@pytest.fixture
def db() -> FakeDatabase:
    return FakeDatabase()


@pytest.fixture
def queue() -> FakeQueue:
    return FakeQueue()


@pytest.fixture
def client(db: FakeDatabase, queue: FakeQueue):
    app = create_app(Settings(postgres_password="unused"), db=db, queue=queue)
    with TestClient(app) as test_client:  # `with` runs the lifespan startup/shutdown
        yield test_client
