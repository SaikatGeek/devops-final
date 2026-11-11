"""Entry point: `python -m app`. Sets up JSON logging, then serves with uvicorn."""

import uvicorn

from .config import Settings
from .logging_setup import setup_logging
from .main import create_app


def main() -> None:
    settings = Settings.from_env()
    setup_logging(settings.service_name, settings.log_level)
    uvicorn.run(
        create_app(settings),
        host="0.0.0.0",
        port=settings.port,
        log_config=None,  # keep our JSON handler instead of uvicorn's text format
        access_log=False,  # RequestLogMiddleware writes one JSON line per request
        timeout_graceful_shutdown=10,  # finish in-flight requests on SIGTERM
    )


if __name__ == "__main__":
    main()
