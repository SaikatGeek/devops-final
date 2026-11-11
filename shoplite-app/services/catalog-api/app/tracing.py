"""OpenTelemetry tracing setup.

Spans are always created, so every log line carries a real trace_id. They are
exported over OTLP/HTTP only when OTEL_EXPORTER_OTLP_ENDPOINT (or
OTEL_EXPORTER_OTLP_TRACES_ENDPOINT) is set, e.g. http://tempo:4318.
"""

import logging
import os

from opentelemetry import trace
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

log = logging.getLogger("shoplite.tracing")


def otlp_endpoint() -> str | None:
    return os.environ.get("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT") or os.environ.get(
        "OTEL_EXPORTER_OTLP_ENDPOINT"
    ) or None


def setup_tracing(service_name: str) -> TracerProvider:
    # Resource.create also merges OTEL_RESOURCE_ATTRIBUTES (e.g. deployment.environment=prod).
    resource = Resource.create({"service.name": service_name, "service.namespace": "shoplite"})
    provider = TracerProvider(resource=resource)

    endpoint = otlp_endpoint()
    if endpoint:
        # Imported here so the exporter (and protobuf) only loads when it is used.
        from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter

        provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
        log.info("trace export enabled", extra={"otlp_endpoint": endpoint})
    else:
        log.info("trace export disabled: OTEL_EXPORTER_OTLP_ENDPOINT not set")

    trace.set_tracer_provider(provider)
    return provider
