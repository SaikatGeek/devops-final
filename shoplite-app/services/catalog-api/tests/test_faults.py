"""catalog-api's two fault-injection flags (question 1.5): CHAOS_LATENCY_MS and CHAOS_ERROR_RATE.

Off by default, deterministic in tests (the random source is injected), and never
named in logs, span names or responses.
"""

import asyncio
import json
import logging
import random

import pytest
from fastapi.testclient import TestClient
from prometheus_client import REGISTRY

from app.config import ConfigError, Settings
from app.faults import LATENCY_SHARE, FaultInjector
from app.main import create_app


class FixedRandom:
    """Stand-in for random.Random that always draws the same number and counts the draws."""

    def __init__(self, value: float) -> None:
        self.value = value
        self.draws = 0

    def random(self) -> float:
        self.draws += 1
        return self.value


class SleepRecorder:
    """Stand-in for asyncio.sleep: remembers the delays instead of waiting."""

    def __init__(self) -> None:
        self.calls: list[float] = []

    async def __call__(self, seconds: float) -> None:
        self.calls.append(seconds)


def client_with(db, queue, faults: FaultInjector) -> TestClient:
    return TestClient(create_app(Settings(postgres_password="unused"), db=db, queue=queue, faults=faults))


def sample(name: str, **labels) -> float:
    return REGISTRY.get_sample_value(name, labels) or 0.0


# ---- configuration ----


def test_flags_are_off_by_default(monkeypatch):
    monkeypatch.setenv("POSTGRES_PASSWORD", "unused")
    monkeypatch.delenv("CHAOS_LATENCY_MS", raising=False)
    monkeypatch.delenv("CHAOS_ERROR_RATE", raising=False)
    settings = Settings.from_env()
    assert settings.chaos_latency_ms == 0
    assert settings.chaos_error_rate == 0.0


def test_flag_values_are_read_from_the_environment(monkeypatch):
    monkeypatch.setenv("POSTGRES_PASSWORD", "unused")
    monkeypatch.setenv("CHAOS_LATENCY_MS", "800")
    monkeypatch.setenv("CHAOS_ERROR_RATE", "0.1")
    settings = Settings.from_env()
    assert settings.chaos_latency_ms == 800
    assert settings.chaos_error_rate == 0.1


@pytest.mark.parametrize(
    ("name", "value"),
    [
        ("CHAOS_LATENCY_MS", "-1"),
        ("CHAOS_LATENCY_MS", "slow"),
        ("CHAOS_ERROR_RATE", "1.5"),
        ("CHAOS_ERROR_RATE", "-0.1"),
        ("CHAOS_ERROR_RATE", "nan"),
        ("CHAOS_ERROR_RATE", "10%"),
    ],
)
def test_invalid_flag_value_stops_startup(monkeypatch, name, value):
    monkeypatch.setenv("POSTGRES_PASSWORD", "unused")
    monkeypatch.setenv(name, value)
    with pytest.raises(ConfigError):
        Settings.from_env()


def test_disabled_faults_never_fire_or_draw_random_numbers():
    rng = FixedRandom(0.0)  # would hit every request if a fault were on
    sleep = SleepRecorder()
    faults = FaultInjector(rng=rng, sleep=sleep)
    asyncio.run(faults.maybe_delay())
    assert faults.should_fail() is False
    assert sleep.calls == []
    assert rng.draws == 0


# ---- CHAOS_LATENCY_MS ----


def test_latency_is_added_to_get_product_when_drawn(db, queue):
    sleep = SleepRecorder()
    faults = FaultInjector(latency_ms=750, rng=FixedRandom(LATENCY_SHARE - 0.01), sleep=sleep)
    with client_with(db, queue, faults) as client:
        response = client.get("/products/1")
    assert response.status_code == 200
    assert sleep.calls == [0.75]


def test_latency_is_skipped_when_not_drawn(db, queue):
    sleep = SleepRecorder()
    faults = FaultInjector(latency_ms=750, rng=FixedRandom(LATENCY_SHARE), sleep=sleep)
    with client_with(db, queue, faults) as client:
        assert client.get("/products/1").status_code == 200
    assert sleep.calls == []


def test_latency_hits_only_get_product(db, queue):
    sleep = SleepRecorder()
    faults = FaultInjector(latency_ms=750, rng=FixedRandom(0.0), sleep=sleep)
    with client_with(db, queue, faults) as client:
        client.get("/products")
        order_id = client.post("/orders", json={"product_id": 1, "quantity": 1}).json()["id"]
        client.get(f"/orders/{order_id}")
        client.get("/readyz")
    assert sleep.calls == []


def test_latency_hits_about_30_percent_of_requests():
    sleep = SleepRecorder()
    faults = FaultInjector(latency_ms=100, rng=random.Random(7), sleep=sleep)

    async def many_requests():
        for _ in range(2000):
            await faults.maybe_delay()

    asyncio.run(many_requests())
    assert 0.27 < len(sleep.calls) / 2000 < 0.33


# ---- CHAOS_ERROR_RATE ----


def test_error_rate_answers_500_before_touching_the_database(db, queue):
    created_before = sample("orders_created_total")
    errors_before = sample("http_requests_total", method="POST", route="/orders", status="500")
    with client_with(db, queue, FaultInjector(error_rate=1.0)) as client:
        response = client.post("/orders", json={"product_id": 1, "quantity": 1})
    assert response.status_code == 500
    assert response.json() == {"detail": "internal server error"}  # same body as any unhandled error
    assert db.orders == {} and queue.messages == []
    assert sample("orders_created_total") == created_before
    # The 5xx is counted, which is what the HighErrorRate alert watches.
    assert sample("http_requests_total", method="POST", route="/orders", status="500") - errors_before == 1


def test_error_rate_hits_only_post_orders(db, queue):
    with client_with(db, queue, FaultInjector(error_rate=1.0)) as client:
        assert client.get("/products").status_code == 200
        assert client.get("/products/1").status_code == 200
        assert client.get("/orders/1").status_code == 404  # no order exists; not a 500


def test_error_rate_hits_that_fraction_of_orders():
    faults = FaultInjector(error_rate=0.1, rng=random.Random(11))
    hits = sum(faults.should_fail() for _ in range(5000))
    assert 0.085 < hits / 5000 < 0.115


# ---- nothing names the flags ----


def test_logs_spans_and_responses_never_name_the_flags(db, queue, spans, caplog):
    """Q8 has to be solved from symptoms, so nothing the API emits may name a flag."""
    faults = FaultInjector(latency_ms=5, error_rate=1.0, rng=FixedRandom(0.0), sleep=SleepRecorder())
    caplog.set_level(logging.DEBUG)
    with client_with(db, queue, faults) as client:
        emitted = [
            client.get("/products/1").text,
            client.post("/orders", json={"product_id": 1, "quantity": 1}).text,
        ]

    emitted += [json.dumps(vars(record), default=str) for record in caplog.records]
    emitted += [s.name + json.dumps(dict(s.attributes), default=str) for s in spans.get_finished_spans()]
    assert any("request completed" in text for text in emitted)  # the logs were captured
    assert not [text for text in emitted if "chaos" in text.lower()]
