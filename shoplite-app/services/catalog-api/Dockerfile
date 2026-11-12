# syntax=docker/dockerfile:1

ARG PYTHON_IMAGE=python:3.12-alpine

# ---- builder: install runtime dependencies into a virtualenv ----
# The venv gets no pip of its own (13 MB the runtime never uses); the base image's
# pip installs into it with --python.
FROM ${PYTHON_IMAGE} AS builder
ENV PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_ROOT_USER_ACTION=ignore
WORKDIR /build
COPY requirements.txt .
RUN python -m venv --without-pip /opt/venv \
 && pip --python /opt/venv/bin/python install -r requirements.txt

# ---- test: builder + dev dependencies; `docker build --target test` then run it ----
FROM builder AS test
COPY requirements-dev.txt .
RUN pip --python /opt/venv/bin/python install -r requirements-dev.txt
WORKDIR /src
COPY app ./app
COPY tests ./tests
ENV PYTHONDONTWRITEBYTECODE=1
CMD ["/opt/venv/bin/python", "-m", "pytest", "-q"]

# ---- runtime: only the virtualenv and the app code, running as a non-root user ----
FROM ${PYTHON_IMAGE} AS runtime
ENV PATH=/opt/venv/bin:$PATH \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
RUN addgroup -S -g 10001 app \
 && adduser -S -D -H -u 10001 -G app app
WORKDIR /app
COPY --from=builder /opt/venv /opt/venv
COPY app ./app
USER 10001:10001
EXPOSE 8000
HEALTHCHECK --interval=10s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO /dev/null http://127.0.0.1:8000/healthz || exit 1
CMD ["python", "-m", "app"]
