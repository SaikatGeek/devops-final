"""The two Q6.2 metrics owned by order-worker."""

import asyncio

from prometheus_client import REGISTRY

from tests.fakes import FakeConsumer, FakeStore, message
from worker.main import Worker
from worker.processor import OrderProcessor


def sample(name: str, **labels) -> float:
    return REGISTRY.get_sample_value(name, labels) or 0.0


def processor(store: FakeStore) -> OrderProcessor:
    return OrderProcessor(store, min_seconds=0.0, max_seconds=0.0, cpu_seconds=0.0)


def test_processed_counter_by_result():
    store = FakeStore({1: "PENDING", 2: "COMPLETED", 3: "PENDING"})
    store_failing = FakeStore({4: "PENDING"})
    store_failing.fail_on_complete = True
    before = {r: sample("orders_processed_total", result=r) for r in ("completed", "skipped", "invalid", "failed")}

    async def scenario():
        await processor(store).handle(message(1))
        await processor(store).handle(message(3))
        await processor(store).handle(message(2))
        await processor(store).handle("garbage")
        await processor(store_failing).handle(message(4))

    asyncio.run(scenario())
    delta = {r: sample("orders_processed_total", result=r) - before[r] for r in before}
    assert delta == {"completed": 2, "skipped": 1, "invalid": 1, "failed": 1}


def test_processing_histogram_observes_finished_orders_only():
    store = FakeStore({10: "PENDING"})
    before = sample("order_processing_seconds_count")
    asyncio.run(processor(store).handle(message(10)))
    asyncio.run(processor(store).handle(message(10)))  # duplicate -> skipped, not observed
    assert sample("order_processing_seconds_count") - before == 1


def test_metrics_served_over_http():
    worker = Worker(processor(FakeStore()), FakeConsumer(), concurrency=1, http_port=0)

    async def scenario():
        task = asyncio.create_task(worker.run_until_stopped())
        await asyncio.sleep(0.05)
        reader, writer = await asyncio.open_connection("127.0.0.1", worker.http.port)
        writer.write(b"GET /metrics HTTP/1.1\r\nAccept: application/openmetrics-text\r\n\r\n")
        await writer.drain()
        response = await reader.read()
        writer.close()
        worker.request_stop()
        await task
        return response.decode()

    response = asyncio.run(scenario())
    assert response.startswith("HTTP/1.1 200 OK")
    assert "Content-Type: application/openmetrics-text" in response
    assert 'orders_processed_total{result="completed"}' in response
    assert "order_processing_seconds_bucket" in response
