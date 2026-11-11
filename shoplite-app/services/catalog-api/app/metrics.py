"""Prometheus metrics for catalog-api (names and labels exactly as Q6.2 requires).

/metrics answers in OpenMetrics format when the scraper asks for it (Prometheus
does), because only that format carries exemplars: the trace_id attached to a
latency observation, which lets Grafana jump from a slow bucket to its trace.
"""

import prometheus_client
from prometheus_client import REGISTRY, Counter, Gauge, Histogram
from prometheus_client.exposition import choose_encoder

from .logging_setup import current_trace_id

# Drop the extra *_created series; they add noise and nothing we query.
prometheus_client.disable_created_metrics()

HTTP_REQUESTS = Counter(
    "http_requests_total",
    "HTTP requests handled, by method, route template and status code.",
    ["method", "route", "status"],
)

# Default buckets (5 ms .. 10 s) include 0.5 and 1.0, the HighLatency and SLO thresholds.
HTTP_DURATION = Histogram(
    "http_request_duration_seconds",
    "HTTP request latency in seconds, by method and route template.",
    ["method", "route"],
)

ORDERS_CREATED = Counter(
    "orders_created_total",
    "Orders accepted by POST /orders and pushed to the queue.",
)

ORDER_QUEUE_DEPTH = Gauge(
    "order_queue_depth",
    "Messages waiting in the Redis list orders:pending (read at scrape time).",
)


def exemplar() -> dict[str, str] | None:
    """Exemplar labels for the current request, or None when no trace is active."""
    trace_id = current_trace_id()
    return {"trace_id": trace_id} if trace_id else None


def render(accept_header: str | None) -> tuple[bytes, str]:
    """Serialize all metrics in the format the scraper asked for."""
    encoder, content_type = choose_encoder(accept_header or "")
    return encoder(REGISTRY), content_type
