"""Pure ASGI middleware that logs one JSON line per HTTP request.

The `route` field is the route template (`/products/{id}`), not the raw path, so
logs and (later) metrics stay low-cardinality.
"""

import logging
import time

from starlette.types import ASGIApp, Message, Receive, Scope, Send

log = logging.getLogger("shoplite.http")

# Probe and scrape endpoints are hit every few seconds; keep them out of INFO logs.
_QUIET_ROUTES = {"/healthz", "/readyz", "/metrics"}


def route_template(scope: Scope) -> str:
    """Matched route template, or a fixed label for requests no route matched."""
    route = scope.get("route")
    return getattr(route, "path", None) or "unmatched"


class RequestLogMiddleware:
    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        start = time.perf_counter()
        status = 500  # assume failure until the app sends a response start

        async def send_wrapper(message: Message) -> None:
            nonlocal status
            if message["type"] == "http.response.start":
                status = message["status"]
            await send(message)

        try:
            await self.app(scope, receive, send_wrapper)
        finally:
            route = route_template(scope)
            if route in _QUIET_ROUTES:
                # A failing probe (e.g. /readyz 503 while Redis is down) is a warning, not an
                # application error; keeps ERROR logs meaningful for alert investigation.
                level = logging.WARNING if status >= 500 else logging.DEBUG
            else:
                level = logging.ERROR if status >= 500 else logging.INFO
            log.log(
                level,
                "request completed",
                extra={
                    "method": scope["method"],
                    "route": route,
                    "path": scope["path"],
                    "status": status,
                    "duration_ms": round((time.perf_counter() - start) * 1000, 2),
                },
            )
