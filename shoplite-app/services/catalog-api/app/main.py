"""catalog-api HTTP routes.

`create_app` takes the database and queue as arguments so unit tests can pass
in-memory fakes instead of real PostgreSQL and Redis.
"""

import asyncio
import logging
from collections.abc import AsyncIterator, Awaitable, Callable
from contextlib import asynccontextmanager
from datetime import datetime
from typing import Literal, Protocol

from fastapi import FastAPI, HTTPException, Request, Response
from fastapi.responses import JSONResponse
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from pydantic import BaseModel, Field

from .config import Settings
from .db import INT4_MAX, Database
from .metrics import ORDER_QUEUE_DEPTH, ORDERS_CREATED, exemplar, render
from .middleware import ObservabilityMiddleware
from .order_queue import RedisQueue, build_message, publish_span

log = logging.getLogger("shoplite.api")

READINESS_TIMEOUT_SECONDS = 2.0
MAX_ORDER_QUANTITY = 1000


class Store(Protocol):
    async def ping(self) -> None: ...
    async def list_products(self) -> list[dict]: ...
    async def get_product(self, product_id: int) -> dict | None: ...
    async def create_order(self, product_id: int, quantity: int) -> dict | None: ...
    async def get_order(self, order_id: int) -> dict | None: ...
    async def mark_order_failed(self, order_id: int) -> None: ...
    async def close(self) -> None: ...


class OrderQueue(Protocol):
    async def ping(self) -> None: ...
    async def enqueue(self, message: str) -> None: ...
    async def depth(self) -> int: ...
    async def close(self) -> None: ...


class Product(BaseModel):
    id: int
    name: str
    price: float
    stock: int


class OrderIn(BaseModel):
    product_id: int = Field(ge=1, le=INT4_MAX)
    quantity: int = Field(ge=1, le=MAX_ORDER_QUANTITY)


class Order(BaseModel):
    id: int
    product_id: int
    quantity: int
    status: Literal["PENDING", "PROCESSING", "COMPLETED", "FAILED"]
    created_at: datetime
    completed_at: datetime | None


async def _check(name: str, probe: Callable[[], Awaitable[None]]) -> bool:
    try:
        await asyncio.wait_for(probe(), timeout=READINESS_TIMEOUT_SECONDS)
        return True
    except Exception as exc:  # any failure means "not ready", never a crash
        log.warning("readiness check failed", extra={"check": name, "error": repr(exc)})
        return False


def create_app(
    settings: Settings | None = None,
    db: Store | None = None,
    queue: OrderQueue | None = None,
) -> FastAPI:
    settings = settings or Settings.from_env()
    db = db or Database(settings)
    queue = queue or RedisQueue(settings.redis_url)

    @asynccontextmanager
    async def lifespan(_: FastAPI) -> AsyncIterator[None]:
        log.info("catalog-api starting")
        yield
        log.info("catalog-api shutting down")
        await asyncio.gather(db.close(), queue.close(), return_exceptions=True)

    app = FastAPI(title="ShopLite catalog-api", lifespan=lifespan)
    app.add_middleware(ObservabilityMiddleware)

    @app.get("/healthz")
    async def healthz() -> dict:
        """Liveness: the process is up and serving HTTP. Checks no dependencies."""
        return {"status": "ok"}

    @app.get("/readyz")
    async def readyz() -> JSONResponse:
        """Readiness: both PostgreSQL and Redis answer within the timeout."""
        db_ok, queue_ok = await asyncio.gather(_check("database", db.ping), _check("queue", queue.ping))
        ready = db_ok and queue_ok
        body = {
            "status": "ready" if ready else "not ready",
            "checks": {
                "database": "ok" if db_ok else "fail",
                "queue": "ok" if queue_ok else "fail",
            },
        }
        return JSONResponse(body, status_code=200 if ready else 503)

    @app.get("/metrics", include_in_schema=False)
    async def metrics(request: Request) -> Response:
        """Prometheus scrape endpoint. Queue depth is read from Redis at scrape time."""
        try:
            depth = await asyncio.wait_for(queue.depth(), timeout=READINESS_TIMEOUT_SECONDS)
            ORDER_QUEUE_DEPTH.set(depth)
        except Exception as exc:
            # Unknown is better than a stale number: NaN shows as a gap in Grafana.
            ORDER_QUEUE_DEPTH.set(float("nan"))
            log.warning("queue depth unavailable", extra={"error": repr(exc)})
        body, content_type = render(request.headers.get("accept"))
        return Response(content=body, media_type=content_type)

    @app.get("/products", response_model=list[Product])
    async def list_products() -> list[dict]:
        return await db.list_products()

    @app.get("/products/{id}", response_model=Product)
    async def get_product(id: int) -> dict:
        product = await db.get_product(id)
        if product is None:
            raise HTTPException(status_code=404, detail="product not found")
        return product

    @app.post("/orders", response_model=Order, status_code=201)
    async def create_order(order_in: OrderIn) -> dict:
        """Store a PENDING order, then hand it to order-worker through the queue.

        The insert is committed before the push, so the worker never pops an order
        it cannot see yet. If the push fails, the order is marked FAILED instead of
        staying PENDING forever, and the client gets 503.
        """
        order = await db.create_order(order_in.product_id, order_in.quantity)
        if order is None:
            raise HTTPException(status_code=404, detail="product not found")

        try:
            with publish_span(order["id"]):
                await queue.enqueue(build_message(order["id"]))
        except Exception:
            log.exception("enqueue failed", extra={"order_id": order["id"]})
            await db.mark_order_failed(order["id"])
            raise HTTPException(status_code=503, detail="order queue unavailable") from None

        ORDERS_CREATED.inc(exemplar=exemplar())
        log.info(
            "order created",
            extra={"order_id": order["id"], "product_id": order_in.product_id, "quantity": order_in.quantity},
        )
        return order

    @app.get("/orders/{id}", response_model=Order)
    async def get_order(id: int) -> dict:
        order = await db.get_order(id)
        if order is None:
            raise HTTPException(status_code=404, detail="order not found")
        return order

    @app.exception_handler(Exception)
    async def unhandled(request: Request, exc: Exception) -> JSONResponse:
        log.exception("unhandled error", extra={"path": request.url.path})
        return JSONResponse({"detail": "internal server error"}, status_code=500)

    # SERVER span per request, named by route template ("GET /products/{id}"). It
    # wraps everything above, so logs, exemplars and DB spans all share its trace_id.
    # Probe and scrape requests get no trace; the per-request ASGI receive/send
    # sub-spans are dropped as noise.
    FastAPIInstrumentor.instrument_app(
        app,
        excluded_urls="healthz,readyz,metrics",
        exclude_spans=["receive", "send"],
    )
    return app
