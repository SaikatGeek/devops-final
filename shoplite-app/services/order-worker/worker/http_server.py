"""Minimal HTTP server for the worker's probe (and later metrics) endpoints.

The worker is not a web app, so instead of a framework it uses asyncio's built-in
TCP server. It only understands `GET <path>`, which is all Kubernetes probes and
Prometheus scrapes send.
"""

import asyncio
import logging
from collections.abc import Callable

log = logging.getLogger("shoplite.worker.http")

# A handler gets the request headers (lower-case names) and returns
# (status code, content type, body).
Handler = Callable[[dict[str, str]], tuple[int, str, bytes]]

_REASONS = {200: "OK", 404: "Not Found", 405: "Method Not Allowed", 503: "Service Unavailable"}


class HttpServer:
    def __init__(self, port: int, routes: dict[str, Handler], host: str = "0.0.0.0") -> None:
        self.host = host
        self.port = port
        self.routes = routes
        self._server: asyncio.Server | None = None

    async def start(self) -> None:
        self._server = await asyncio.start_server(self._handle, self.host, self.port)
        self.port = self._server.sockets[0].getsockname()[1]  # real port when 0 was asked
        log.info("http server listening", extra={"port": self.port})

    async def close(self) -> None:
        if self._server is not None:
            self._server.close()
            await self._server.wait_closed()

    async def _handle(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter) -> None:
        try:
            request_line = await asyncio.wait_for(reader.readline(), timeout=5)
            headers: dict[str, str] = {}
            for _ in range(100):  # Accept matters for /metrics content negotiation
                line = await asyncio.wait_for(reader.readline(), timeout=5)
                if line in (b"\r\n", b"\n", b""):
                    break
                name, _, value = line.decode("latin-1").partition(":")
                headers[name.strip().lower()] = value.strip()

            parts = request_line.decode("latin-1").split()
            method = parts[0] if parts else ""
            path = parts[1].split("?", 1)[0] if len(parts) > 1 else ""

            if method != "GET":
                status, ctype, body = 405, "text/plain", b"method not allowed\n"
            elif path in self.routes:
                status, ctype, body = self.routes[path](headers)
            else:
                status, ctype, body = 404, "text/plain", b"not found\n"

            head = (
                f"HTTP/1.1 {status} {_REASONS.get(status, '')}\r\n"
                f"Content-Type: {ctype}\r\n"
                f"Content-Length: {len(body)}\r\n"
                "Connection: close\r\n\r\n"
            )
            writer.write(head.encode("latin-1") + body)
            await writer.drain()
        except Exception as exc:  # a broken client must never affect the worker
            log.debug("http request failed", extra={"error": repr(exc)})
        finally:
            writer.close()
