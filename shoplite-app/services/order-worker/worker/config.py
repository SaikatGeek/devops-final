"""Configuration, read only from environment variables (12-factor style)."""

import os
from dataclasses import dataclass


class ConfigError(RuntimeError):
    """Raised when a required environment variable is missing or invalid."""


def _require(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        raise ConfigError(f"environment variable {name} is required")
    return value


def _number(name: str, default, cast):
    raw = os.environ.get(name)
    if raw is None or raw == "":
        return default
    try:
        return cast(raw)
    except ValueError as exc:
        raise ConfigError(f"environment variable {name} must be a {cast.__name__}, got {raw!r}") from exc


_TRUE = {"1", "true", "yes", "on"}
_FALSE = {"0", "false", "no", "off"}


def _bool(name: str, default: bool) -> bool:
    raw = os.environ.get(name)
    if raw is None or raw.strip() == "":
        return default
    value = raw.strip().lower()
    if value in _TRUE:
        return True
    if value in _FALSE:
        return False
    raise ConfigError(f"environment variable {name} must be true or false, got {raw!r}")


@dataclass(frozen=True)
class Settings:
    service_name: str = "order-worker"
    log_level: str = "INFO"
    http_port: int = 8001  # /healthz and /metrics

    postgres_host: str = "localhost"
    postgres_port: int = 5432
    postgres_db: str = "shoplite"
    postgres_user: str = "shoplite"
    postgres_password: str = ""

    redis_url: str = "redis://localhost:6379/0"

    # Orders processed in parallel by one worker process.
    concurrency: int = 4
    # Each order takes a random time in [min, max] seconds; cpu_seconds of it is real
    # CPU work so the CPU-based HPA has something to scale on.
    processing_min_seconds: float = 1.0
    processing_max_seconds: float = 2.0
    processing_cpu_seconds: float = 0.2

    # Fault injection for the Q8 exercise (question 1.5), off by default.
    # CHAOS_MEMORY_LEAK: keep ~1 MB per processed order (processor.py).
    # CHAOS_SLOW_DB: run SELECT pg_sleep(2) before each database update (store.py).
    chaos_memory_leak: bool = False
    chaos_slow_db: bool = False

    @classmethod
    def from_env(cls) -> "Settings":
        settings = cls(
            service_name=os.environ.get("SERVICE_NAME", "order-worker"),
            log_level=os.environ.get("LOG_LEVEL", "INFO").upper(),
            http_port=_number("HTTP_PORT", 8001, int),
            postgres_host=os.environ.get("POSTGRES_HOST", "localhost"),
            postgres_port=_number("POSTGRES_PORT", 5432, int),
            postgres_db=os.environ.get("POSTGRES_DB", "shoplite"),
            postgres_user=os.environ.get("POSTGRES_USER", "shoplite"),
            postgres_password=_require("POSTGRES_PASSWORD"),
            redis_url=os.environ.get("REDIS_URL", "redis://localhost:6379/0"),
            concurrency=_number("WORKER_CONCURRENCY", 4, int),
            processing_min_seconds=_number("PROCESSING_MIN_SECONDS", 1.0, float),
            processing_max_seconds=_number("PROCESSING_MAX_SECONDS", 2.0, float),
            processing_cpu_seconds=_number("PROCESSING_CPU_SECONDS", 0.2, float),
            chaos_memory_leak=_bool("CHAOS_MEMORY_LEAK", False),
            chaos_slow_db=_bool("CHAOS_SLOW_DB", False),
        )
        if settings.concurrency < 1:
            raise ConfigError("WORKER_CONCURRENCY must be at least 1")
        if not 0 <= settings.processing_min_seconds <= settings.processing_max_seconds:
            raise ConfigError("need 0 <= PROCESSING_MIN_SECONDS <= PROCESSING_MAX_SECONDS")
        return settings
