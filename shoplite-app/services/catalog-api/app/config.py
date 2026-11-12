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


def _int(name: str, default: int) -> int:
    raw = os.environ.get(name)
    if raw is None or raw == "":
        return default
    try:
        return int(raw)
    except ValueError as exc:
        raise ConfigError(f"environment variable {name} must be an integer, got {raw!r}") from exc


def _float(name: str, default: float) -> float:
    raw = os.environ.get(name)
    if raw is None or raw == "":
        return default
    try:
        return float(raw)
    except ValueError as exc:
        raise ConfigError(f"environment variable {name} must be a number, got {raw!r}") from exc


@dataclass(frozen=True)
class Settings:
    service_name: str = "catalog-api"
    log_level: str = "INFO"
    port: int = 8000

    postgres_host: str = "localhost"
    postgres_port: int = 5432
    postgres_db: str = "shoplite"
    postgres_user: str = "shoplite"
    postgres_password: str = ""

    redis_url: str = "redis://localhost:6379/0"

    # Fault injection for the Q8 exercise (question 1.5), off by default; see faults.py.
    chaos_latency_ms: int = 0
    chaos_error_rate: float = 0.0

    @classmethod
    def from_env(cls) -> "Settings":
        settings = cls(
            service_name=os.environ.get("SERVICE_NAME", "catalog-api"),
            log_level=os.environ.get("LOG_LEVEL", "INFO").upper(),
            port=_int("PORT", 8000),
            postgres_host=os.environ.get("POSTGRES_HOST", "localhost"),
            postgres_port=_int("POSTGRES_PORT", 5432),
            postgres_db=os.environ.get("POSTGRES_DB", "shoplite"),
            postgres_user=os.environ.get("POSTGRES_USER", "shoplite"),
            postgres_password=_require("POSTGRES_PASSWORD"),
            redis_url=os.environ.get("REDIS_URL", "redis://localhost:6379/0"),
            chaos_latency_ms=_int("CHAOS_LATENCY_MS", 0),
            chaos_error_rate=_float("CHAOS_ERROR_RATE", 0.0),
        )
        if settings.chaos_latency_ms < 0:
            raise ConfigError("CHAOS_LATENCY_MS must be 0 or more")
        if not 0.0 <= settings.chaos_error_rate <= 1.0:  # also rejects nan and inf
            raise ConfigError("CHAOS_ERROR_RATE must be between 0 and 1")
        return settings
