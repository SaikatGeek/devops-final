"""order-worker's two fault-injection flags (question 1.5): CHAOS_MEMORY_LEAK and CHAOS_SLOW_DB."""

import asyncio
import json
import logging

import pytest

from tests.fakes import FakePool, FakeStore, message
from worker.config import ConfigError, Settings
from worker.processor import RETAINED_BYTES_PER_ORDER, OrderProcessor
from worker.store import SLEEP_SQL, OrderStore


def processor(store, memory_leak: bool = False) -> OrderProcessor:
    return OrderProcessor(store, min_seconds=0.0, max_seconds=0.0, cpu_seconds=0.0, memory_leak=memory_leak)


def store_with(slow_db: bool) -> tuple[OrderStore, FakePool]:
    pool = FakePool()
    return OrderStore(Settings(postgres_password="unused", chaos_slow_db=slow_db), pool=pool), pool


def test_flags_are_off_by_default(monkeypatch):
    monkeypatch.setenv("POSTGRES_PASSWORD", "unused")
    monkeypatch.delenv("CHAOS_MEMORY_LEAK", raising=False)
    monkeypatch.delenv("CHAOS_SLOW_DB", raising=False)
    settings = Settings.from_env()
    assert settings.chaos_memory_leak is False
    assert settings.chaos_slow_db is False


@pytest.mark.parametrize(
    ("raw", "expected"),
    [("true", True), ("1", True), ("YES", True), ("on", True), ("false", False), ("0", False), ("off", False), ("", False)],
)
def test_flag_values_are_read_from_the_environment(monkeypatch, raw, expected):
    monkeypatch.setenv("POSTGRES_PASSWORD", "unused")
    monkeypatch.setenv("CHAOS_MEMORY_LEAK", raw)
    monkeypatch.setenv("CHAOS_SLOW_DB", raw)
    settings = Settings.from_env()
    assert settings.chaos_memory_leak is expected
    assert settings.chaos_slow_db is expected


@pytest.mark.parametrize("name", ["CHAOS_MEMORY_LEAK", "CHAOS_SLOW_DB"])
def test_invalid_flag_value_stops_startup(monkeypatch, name):
    monkeypatch.setenv("POSTGRES_PASSWORD", "unused")
    monkeypatch.setenv(name, "sometimes")
    with pytest.raises(ConfigError):
        Settings.from_env()


def test_memory_leak_keeps_about_1_mb_per_processed_order():
    store = FakeStore({1: "PENDING", 2: "PENDING", 3: "COMPLETED"})
    worker = processor(store, memory_leak=True)

    async def scenario():
        for order_id in (1, 2, 3):  # order 3 is skipped: nothing processed, nothing kept
            await worker.handle(message(order_id))

    asyncio.run(scenario())
    assert len(worker.retained) == 2
    assert all(len(block) == RETAINED_BYTES_PER_ORDER == 1024 * 1024 for block in worker.retained)


def test_no_memory_is_kept_when_flag_is_off():
    worker = processor(FakeStore({1: "PENDING"}))
    asyncio.run(worker.handle(message(1)))
    assert worker.retained == []


def test_slow_db_runs_pg_sleep_before_every_update(spans):
    store, pool = store_with(slow_db=True)

    async def scenario():
        await store.start_processing(1)
        await store.complete(1)
        await store.fail(2)

    asyncio.run(scenario())
    assert pool.statements[0::2] == [SLEEP_SQL] * 3
    assert all(statement.startswith("UPDATE orders") for statement in pool.statements[1::2])

    # In the trace it is an ordinary DB span right before each UPDATE.
    finished = spans.get_finished_spans()
    assert [s.name for s in finished] == ["SELECT", "UPDATE orders"] * 3
    assert finished[0].attributes["db.query.text"] == "SELECT pg_sleep(2)"


def test_no_pg_sleep_when_flag_is_off(spans):
    store, pool = store_with(slow_db=False)
    asyncio.run(store.start_processing(1))
    assert len(pool.statements) == 1
    assert pool.statements[0].startswith("UPDATE orders")
    assert [s.name for s in spans.get_finished_spans()] == ["UPDATE orders"]


def test_logs_and_spans_never_name_the_flags(spans, caplog):
    """Q8 has to be solved from symptoms, so nothing the worker emits may name a flag."""
    store, _ = store_with(slow_db=True)
    worker = processor(store, memory_leak=True)
    caplog.set_level(logging.DEBUG)

    assert asyncio.run(worker.handle(message(7))) == "completed"

    emitted = [json.dumps(vars(record), default=str) for record in caplog.records]
    emitted += [s.name + json.dumps(dict(s.attributes), default=str) for s in spans.get_finished_spans()]
    assert emitted, "expected some logs and spans to check"
    assert not [text for text in emitted if "chaos" in text.lower()]
