"""Entry point: `python -m worker`."""

import asyncio

from .config import Settings
from .logging_setup import setup_logging
from .main import run


def main() -> None:
    settings = Settings.from_env()
    setup_logging(settings.service_name, settings.log_level)
    asyncio.run(run(settings))


if __name__ == "__main__":
    main()
