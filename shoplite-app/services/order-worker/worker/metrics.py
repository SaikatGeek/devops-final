"""Prometheus metrics for order-worker (names and labels exactly as Q6.2 requires).

Served on the worker's HTTP port at /metrics, in OpenMetrics format when the
scraper asks for it, so exemplars (trace_id) reach Prometheus.
"""

import prometheus_client
from prometheus_client import REGISTRY, Counter, Histogram
from prometheus_client.exposition import choose_encoder

from .logging_setup import current_trace_id

prometheus_client.disable_created_metrics()

ORDERS_PROCESSED = Counter(
    "orders_processed_total",
    "Queue messages handled by the worker, by result.",
    ["result"],
)
# Create every result series at 0, so rate() and "created vs processed" work from the start.
RESULTS = ("completed", "failed", "skipped", "invalid")
for _result in RESULTS:
    ORDERS_PROCESSED.labels(result=_result)

# Normal processing takes 1-2 s; the upper buckets catch CHAOS_SLOW_DB (+2 s per DB update).
ORDER_PROCESSING = Histogram(
    "order_processing_seconds",
    "Time from picking an order up to its final status, in seconds.",
    buckets=(0.5, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0, 4.0, 5.0, 7.5, 10.0, 15.0, 30.0),
)


def exemplar() -> dict[str, str] | None:
    trace_id = current_trace_id()
    return {"trace_id": trace_id} if trace_id else None


def render(accept_header: str | None) -> tuple[bytes, str]:
    encoder, content_type = choose_encoder(accept_header or "")
    return encoder(REGISTRY), content_type
