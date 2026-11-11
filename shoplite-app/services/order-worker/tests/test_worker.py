import asyncio

from tests.fakes import FakeConsumer, FakeStore, message
from worker.main import Worker
from worker.processor import OrderProcessor


def fast_processor(store: FakeStore, seconds: float = 0.0) -> OrderProcessor:
    return OrderProcessor(store, min_seconds=seconds, max_seconds=seconds, cpu_seconds=0.0)


def test_pending_order_is_completed():
    store = FakeStore({1: "PENDING"})
    outcome = asyncio.run(fast_processor(store).handle(message(1)))
    assert outcome == "completed"
    assert store.status[1] == "COMPLETED"


def test_order_not_pending_is_skipped():
    store = FakeStore({1: "COMPLETED"})
    assert asyncio.run(fast_processor(store).handle(message(1))) == "skipped"
    assert asyncio.run(fast_processor(store).handle(message(99))) == "skipped"
    assert store.status == {1: "COMPLETED"}


def test_invalid_message_is_dropped():
    store = FakeStore()
    for raw in ["not json", "{}", '{"order_id": "7"}', '{"order_id": -1}', "[]"]:
        assert asyncio.run(fast_processor(store).handle(raw)) == "invalid"


def test_error_during_processing_marks_order_failed():
    store = FakeStore({5: "PENDING"})
    store.fail_on_complete = True
    assert asyncio.run(fast_processor(store).handle(message(5))) == "failed"
    assert store.status[5] == "FAILED"


def test_sigterm_finishes_in_flight_order_before_exit():
    """Shutdown requested while an order is mid-processing: the order still completes."""
    store = FakeStore({1: "PENDING", 2: "PENDING"})
    queue = FakeConsumer([1, 2])
    worker = Worker(fast_processor(store, seconds=0.2), queue, concurrency=1, http_port=None)

    async def scenario():
        task = asyncio.create_task(worker.run_until_stopped())
        await asyncio.sleep(0.05)  # order 1 has been popped and is being processed
        worker.request_stop("SIGTERM")
        await asyncio.wait_for(task, timeout=2)

    asyncio.run(scenario())
    assert store.status[1] == "COMPLETED"  # in-flight order finished
    assert store.status[2] == "PENDING"  # nothing new was taken after the stop request
    assert len(queue.messages) == 1  # order 2 is still in the queue for the next worker


def test_healthz_endpoint():
    worker = Worker(fast_processor(FakeStore()), FakeConsumer(), concurrency=1, http_port=0)

    async def scenario():
        task = asyncio.create_task(worker.run_until_stopped())
        await asyncio.sleep(0.05)
        reader, writer = await asyncio.open_connection("127.0.0.1", worker.http.port)
        writer.write(b"GET /healthz HTTP/1.1\r\nHost: x\r\n\r\n")
        await writer.drain()
        response = await reader.read()
        writer.close()
        worker.request_stop()
        await task
        return response

    response = asyncio.run(scenario())
    assert response.startswith(b"HTTP/1.1 200 OK")
    assert response.endswith(b'{"status": "ok"}')
