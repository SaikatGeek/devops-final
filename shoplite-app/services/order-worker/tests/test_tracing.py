"""The worker continues the API's trace from the traceparent in the queue message."""

import asyncio
import json
from datetime import datetime, timedelta, timezone

from opentelemetry.trace import SpanKind, StatusCode

from tests.fakes import FakeStore
from worker.processor import OrderProcessor

TRACE_ID = "4bf92f3577b34da6a3ce929d0e0e4736"
PRODUCER_SPAN_ID = "00f067aa0ba902b7"


def processor(store: FakeStore) -> OrderProcessor:
    return OrderProcessor(store, min_seconds=0.0, max_seconds=0.0, cpu_seconds=0.0)


def traced_message(order_id: int) -> str:
    return json.dumps(
        {
            "order_id": order_id,
            "enqueued_at": (datetime.now(timezone.utc) - timedelta(seconds=1)).isoformat(),
            "traceparent": f"00-{TRACE_ID}-{PRODUCER_SPAN_ID}-01",
        }
    )


def test_consumer_span_joins_the_api_trace(spans):
    asyncio.run(processor(FakeStore({1: "PENDING"})).handle(traced_message(1)))

    consumer = next(s for s in spans.get_finished_spans() if s.kind == SpanKind.CONSUMER)
    assert consumer.name == "process orders:pending"
    assert format(consumer.context.trace_id, "032x") == TRACE_ID
    assert format(consumer.parent.span_id, "016x") == PRODUCER_SPAN_ID
    assert consumer.attributes["shoplite.order_id"] == 1
    assert consumer.attributes["shoplite.result"] == "completed"
    assert consumer.attributes["shoplite.queue_wait_ms"] >= 1000


def test_work_and_db_spans_are_children_of_the_consumer_span(spans):
    asyncio.run(processor(FakeStore({2: "PENDING"})).handle(traced_message(2)))

    finished = spans.get_finished_spans()
    consumer = next(s for s in finished if s.kind == SpanKind.CONSUMER)
    work = next(s for s in finished if s.name == "simulate work")
    assert work.parent.span_id == consumer.context.span_id
    assert work.context.trace_id == consumer.context.trace_id


def test_failed_order_marks_span_as_error(spans):
    store = FakeStore({3: "PENDING"})
    store.fail_on_complete = True
    asyncio.run(processor(store).handle(traced_message(3)))

    consumer = next(s for s in spans.get_finished_spans() if s.kind == SpanKind.CONSUMER)
    assert consumer.status.status_code == StatusCode.ERROR
    assert any(e.name == "exception" for e in consumer.events)


def test_message_without_traceparent_starts_a_new_trace(spans):
    asyncio.run(processor(FakeStore({4: "PENDING"})).handle(json.dumps({"order_id": 4})))

    consumer = next(s for s in spans.get_finished_spans() if s.kind == SpanKind.CONSUMER)
    assert consumer.parent is None
    assert consumer.context.trace_id != int(TRACE_ID, 16)
