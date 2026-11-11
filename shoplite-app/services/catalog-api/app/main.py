"""catalog-api HTTP routes.

`create_app` takes the database and queue as arguments so unit tests can pass
in-memory fakes instead of real PostgreSQL and Redis.
"""

import asyncio
import logging
from collections.abc import AsyncIterator, Awaitable, Callable
from contextlib import asynccontextmanager
from typing import Protocol

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from .config import Settings
from .db import Database
from .middleware import RequestLogMiddleware
from .order_queue import RedisQueue

log = logging.getLogger("shoplite.api")

READINESS_TIMEOUT_SECONDS = 2.0


class ProductStore(Protocol):
    async def ping(self) -> None: ...
    async def list_products(self) -> list[dict]: ...
    async def get_product(self, product_id: int) -> dict | None: ...
    async def close(self) -> None: ...


class OrderQueue(Protocol):
    async def ping(self) -> None: ...
    async def close(self) -> None: ...


class Product(BaseModel):
    id: int
    name: str
    price: float
    stock: int


async def _check(name: str, probe: Callable[[], Awaitable[None]]) -> bool:
    try:
        await asyncio.wait_for(probe(), timeout=READINESS_TIMEOUT_SECONDS)
        return True
    except Exception as exc:  # any failure means "not ready", never a crash
        log.warning("readiness check failed", extra={"check": name, "error": repr(exc)})
        return False


def create_app(
    settings: Settings | None = None,
    db: ProductStore | None = None,
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
    app.add_middleware(RequestLogMiddleware)

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

    @app.get("/products", response_model=list[Product])
    async def list_products() -> list[dict]:
        return await db.list_products()

    @app.get("/products/{id}", response_model=Product)
    async def get_product(id: int) -> dict:
        product = await db.get_product(id)
        if product is None:
            raise HTTPException(status_code=404, detail="product not found")
        return product

    @app.exception_handler(Exception)
    async def unhandled(request: Request, exc: Exception) -> JSONResponse:
        log.exception("unhandled error", extra={"path": request.url.path})
        return JSONResponse({"detail": "internal server error"}, status_code=500)

    return app
