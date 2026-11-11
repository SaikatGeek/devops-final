"""Trace propagation through the queue, trace_id in logs, and exemplars."""

import io
import json
import logging
import re

from opentelemetry.trace import SpanKind

from app.logging_setup import JsonFormatter


def test_order_message_carries_the_request_trace(client, queue, spans):
    client.post("/orders", json={"product_id": 1, "quantity": 1})
    message = json.loads(queue.messages[-1])

    # W3C traceparent: version-traceid-spanid-flags
    version, trace_id, parent_span_id, flags = message["traceparent"].split("-")
    assert version == "00"
    assert int(flags, 16) & 0x01  # "sampled" bit set, so the worker records its spans too

    server = next(s for s in spans.get_finished_spans() if s.kind == SpanKind.SERVER)
    producer = next(s for s in spans.get_finished_spans() if s.kind == SpanKind.PRODUCER)
    assert server.name == "POST /orders"
    assert producer.name == "send orders:pending"
    # Same trace; the worker's span will hang under the producer span.
    assert trace_id == format(server.context.trace_id, "032x")
    assert producer.context.trace_id == server.context.trace_id
    assert parent_span_id == format(producer.context.span_id, "016x")


def test_probe_and_scrape_requests_create_no_spans(client, spans):
    client.get("/healthz")
    client.get("/readyz")
    client.get("/metrics")
    assert spans.get_finished_spans() == ()


def test_logs_written_during_a_request_carry_its_trace_id(client, spans):
    # The real JSON handler, which formats (and reads the trace_id) at emit time.
    buffer = io.StringIO()
    handler = logging.StreamHandler(buffer)
    handler.setFormatter(JsonFormatter("catalog-api"))
    logger = logging.getLogger("shoplite.api")
    logger.addHandler(handler)
    logger.setLevel(logging.INFO)
    try:
        client.post("/orders", json={"product_id": 2, "quantity": 1})
    finally:
        logger.removeHandler(handler)

    lines = [json.loads(line) for line in buffer.getvalue().splitlines()]
    order_created = next(line for line in lines if line["message"] == "order created")
    assert set(order_created) >= {"timestamp", "level", "service", "message", "trace_id"}

    server = next(s for s in spans.get_finished_spans() if s.kind == SpanKind.SERVER)
    assert order_created["trace_id"] == format(server.context.trace_id, "032x")


def test_latency_histogram_has_trace_id_exemplars(client, spans):
    client.get("/products/1")
    server = next(s for s in spans.get_finished_spans() if s.kind == SpanKind.SERVER)
    trace_id = format(server.context.trace_id, "032x")

    metrics = client.get("/metrics", headers={"Accept": "application/openmetrics-text"}).text
    exemplars = re.findall(
        r'^http_request_duration_seconds_bucket\{.*route="/products/\{id\}".*\} \S+ # \{trace_id="([0-9a-f]{32})"\}',
        metrics,
        re.MULTILINE,
    )
    assert trace_id in exemplars
