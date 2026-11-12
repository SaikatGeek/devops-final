"""Worker process: N consumer loops plus a small HTTP server, with graceful shutdown.

On SIGTERM (docker stop, Kubernetes pod deletion) the worker stops taking new
messages, lets every consumer finish the order it is holding, then exits.
A message that was already popped is therefore never lost on shutdown.
"""

import asyncio
import json
import logging
import signal
import time
from typing import Protocol

from .config import Settings
from .http_server import HttpServer
from .metrics import render
from .order_queue import RedisConsumer
from .processor import OrderProcessor
from .store import OrderStore

log = logging.getLogger("shoplite.worker")

POP_TIMEOUT_SECONDS = 1.0
RETRY_DELAY_SECONDS = 1.0


class Consumer(Protocol):
    async def pop(self, timeout: float = 1.0) -> str | None: ...
    async def close(self) -> None: ...


class Worker:
    def __init__(
        self,
        processor: OrderProcessor,
        queue: Consumer,
        concurrency: int = 4,
        http_port: int | None = 8001,
    ) -> None:
        self.processor = processor
        self.queue = queue
        self.concurrency = concurrency
        self.stopping = asyncio.Event()
        self._consumers: list[asyncio.Task] = []
        routes = {"/healthz": self._healthz, "/metrics": self._metrics}
        self.http = HttpServer(http_port, routes) if http_port is not None else None

    def _metrics(self, headers: dict[str, str]) -> tuple[int, str, bytes]:
        body, content_type = render(headers.get("accept"))
        return 200, content_type, body

    def _healthz(self, headers: dict[str, str]) -> tuple[int, str, bytes]:
        """Liveness: the event loop answers and no consumer loop has died."""
        alive = all(not t.done() for t in self._consumers) or self.stopping.is_set()
        body = json.dumps({"status": "ok" if alive else "consumer stopped"}).encode()
        return (200 if alive else 503), "application/json", body

    def request_stop(self, signame: str = "manual") -> None:
        if not self.stopping.is_set():
            log.info("shutdown requested, finishing in-flight orders", extra={"signal": signame})
            self.stopping.set()

    async def consume(self, n: int) -> None:
        while not self.stopping.is_set():
            try:
                raw = await self.queue.pop(timeout=POP_TIMEOUT_SECONDS)
            except Exception as exc:
                log.warning("queue pop failed, retrying", extra={"consumer": n, "error": repr(exc)})
                try:  # wait before retrying, but wake up at once on shutdown
                    await asyncio.wait_for(self.stopping.wait(), timeout=RETRY_DELAY_SECONDS)
                except TimeoutError:
                    pass
                continue
            if raw is not None:
                # Not interrupted by shutdown: an order we popped is always finished.
                await self.processor.handle(raw)

    async def run(self) -> None:
        loop = asyncio.get_running_loop()
        for sig in (signal.SIGTERM, signal.SIGINT):
            loop.add_signal_handler(sig, self.request_stop, sig.name)
        await self.run_until_stopped()

    async def run_until_stopped(self) -> None:
        if self.http is not None:
            await self.http.start()
        self._consumers = [asyncio.create_task(self.consume(i)) for i in range(self.concurrency)]
        log.info("order-worker started", extra={"concurrency": self.concurrency})

        await self.stopping.wait()
        started = time.perf_counter()
        await asyncio.gather(*self._consumers, return_exceptions=True)
        if self.http is not None:
            await self.http.close()
        log.info(
            "order-worker stopped",
            extra={"shutdown_ms": round((time.perf_counter() - started) * 1000, 1)},
        )


async def run(settings: Settings) -> None:
    store = OrderStore(settings)
    queue = RedisConsumer(settings.redis_url)
    processor = OrderProcessor(
        store,
        min_seconds=settings.processing_min_seconds,
        max_seconds=settings.processing_max_seconds,
        cpu_seconds=settings.processing_cpu_seconds,
        memory_leak=settings.chaos_memory_leak,
    )
    worker = Worker(processor, queue, settings.concurrency, settings.http_port)
    try:
        await worker.run()
    finally:
        await asyncio.gather(store.close(), queue.close(), return_exceptions=True)
