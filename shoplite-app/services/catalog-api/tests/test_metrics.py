"""The six Q6.2 metrics: four come from catalog-api (the worker exposes the other two).

Metrics live in the process-wide registry, so tests compare before/after values.
"""

import math

from prometheus_client import REGISTRY


def sample(name: str, **labels) -> float:
    return REGISTRY.get_sample_value(name, labels) or 0.0


def test_metrics_endpoint_lists_api_metrics(client):
    client.get("/products")  # make sure the labelled http series exist
    response = client.get("/metrics")
    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/plain")
    for name in (
        "http_requests_total",
        "http_request_duration_seconds_bucket",
        "orders_created_total",
        "order_queue_depth",
    ):
        assert name in response.text


def test_http_metrics_use_route_template_not_raw_path(client):
    before = sample("http_requests_total", method="GET", route="/products/{id}", status="404")
    client.get("/products/777")
    client.get("/products/888")
    after = sample("http_requests_total", method="GET", route="/products/{id}", status="404")
    assert after - before == 2
    assert REGISTRY.get_sample_value(
        "http_requests_total", {"method": "GET", "route": "/products/777", "status": "404"}
    ) is None


def test_latency_histogram_observes_requests(client):
    labels = {"method": "GET", "route": "/products"}
    before = sample("http_request_duration_seconds_count", **labels)
    client.get("/products")
    assert sample("http_request_duration_seconds_count", **labels) - before == 1
    # Thresholds used by the HighLatency alert and the SLO must be real buckets.
    assert REGISTRY.get_sample_value("http_request_duration_seconds_bucket", {**labels, "le": "0.5"}) is not None
    assert REGISTRY.get_sample_value("http_request_duration_seconds_bucket", {**labels, "le": "1.0"}) is not None


def test_probe_and_scrape_requests_are_not_counted(client):
    before = sample("http_requests_total", method="GET", route="/healthz", status="200")
    client.get("/healthz")
    client.get("/metrics")
    assert sample("http_requests_total", method="GET", route="/healthz", status="200") == before


def test_orders_created_counts_only_successful_orders(client, queue):
    before = sample("orders_created_total")
    client.post("/orders", json={"product_id": 1, "quantity": 1})  # 201
    client.post("/orders", json={"product_id": 999, "quantity": 1})  # 404
    queue.healthy = False
    client.post("/orders", json={"product_id": 1, "quantity": 1})  # 503
    assert sample("orders_created_total") - before == 1


def test_queue_depth_is_read_at_scrape_time(client, queue):
    queue.messages = [1, 2, 3]
    client.get("/metrics")
    assert sample("order_queue_depth") == 3
    queue.healthy = False
    client.get("/metrics")
    assert math.isnan(REGISTRY.get_sample_value("order_queue_depth"))


def test_metrics_in_openmetrics_format_when_requested(client):
    response = client.get("/metrics", headers={"Accept": "application/openmetrics-text; version=1.0.0"})
    assert response.headers["content-type"].startswith("application/openmetrics-text")
    assert response.text.rstrip().endswith("# EOF")
