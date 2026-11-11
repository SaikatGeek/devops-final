"""Entry point: `python -m worker`."""

import asyncio

from .config import Settings
from .logging_setup import setup_logging
from .main import run
from .tracing import setup_tracing


def main() -> None:
    settings = Settings.from_env()
    setup_logging(settings.service_name, settings.log_level)
    provider = setup_tracing(settings.service_name)
    try:
        asyncio.run(run(settings))
    finally:
        provider.shutdown()  # flush spans of the last orders before the process exits


if __name__ == "__main__":
    main()
