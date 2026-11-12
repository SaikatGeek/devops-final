"""Fault injection for the Q8 exercise (question 1.5). Every fault is off by default.

CHAOS_LATENCY_MS  adds that many milliseconds to about 30% of GET /products/{id}.
CHAOS_ERROR_RATE  answers that fraction of POST /orders with HTTP 500 (0.1 = 10%),
                  before the database is touched.

From the outside an injected fault looks like an ordinary problem: no log line,
span name or response body names it, so in Q8 it has to be found from metrics,
logs and traces alone. The random source is a constructor argument, so unit
tests decide exactly which requests are hit.
"""

import asyncio
import random
from collections.abc import Awaitable, Callable

# Share of GET /products/{id} requests that get the extra latency.
LATENCY_SHARE = 0.3


class FaultInjector:
    def __init__(
        self,
        latency_ms: int = 0,
        error_rate: float = 0.0,
        rng: random.Random | None = None,
        sleep: Callable[[float], Awaitable[None]] = asyncio.sleep,
    ) -> None:
        self.latency_ms = latency_ms
        self.error_rate = error_rate
        self._rng = rng if rng is not None else random.Random()
        self._sleep = sleep

    async def maybe_delay(self) -> None:
        """Wait latency_ms for about 30% of calls. Off: returns at once, draws nothing."""
        if self.latency_ms > 0 and self._rng.random() < LATENCY_SHARE:
            await self._sleep(self.latency_ms / 1000)

    def should_fail(self) -> bool:
        """True for about error_rate of calls. Off: always False, draws nothing."""
        return self.error_rate > 0 and self._rng.random() < self.error_rate
