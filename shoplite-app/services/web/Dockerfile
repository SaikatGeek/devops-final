# syntax=docker/dockerfile:1

ARG NGINX_IMAGE=nginxinc/nginx-unprivileged:1.30.6-alpine

# Two stages: the test files (fake API, checks) exist only in `test`, never in `runtime`.

# ---- test: the runtime setup plus a fake API; `docker build --target test` then run it ----
FROM ${NGINX_IMAGE} AS test
ENV API_UPSTREAM=127.0.0.1:9000 \
    NGINX_ENTRYPOINT_LOCAL_RESOLVERS=1 \
    NGINX_ENTRYPOINT_WORKER_PROCESSES_AUTOTUNE=1 \
    NGINX_ENTRYPOINT_QUIET_LOGS=1
COPY nginx/default.conf.template /etc/nginx/templates/default.conf.template
COPY public/ /usr/share/nginx/html/
COPY tests/fake-api.conf /etc/nginx/conf.d/fake-api.conf
COPY tests/run.sh /tests/run.sh
CMD ["/bin/sh", "/tests/run.sh"]

# ---- runtime: nginx as the image's non-root user (uid 101) on port 8080 ----
FROM ${NGINX_IMAGE} AS runtime
# API_UPSTREAM: catalog-api's address. In Kubernetes use the full service name
# (catalog-api.<namespace>.svc.cluster.local:8000): nginx's resolver ignores search domains.
# The entrypoint fills NGINX_LOCAL_RESOLVERS from /etc/resolv.conf and sets
# worker_processes from the container's CPU limit instead of the host's CPU count.
ENV API_UPSTREAM=catalog-api:8000 \
    NGINX_ENTRYPOINT_LOCAL_RESOLVERS=1 \
    NGINX_ENTRYPOINT_WORKER_PROCESSES_AUTOTUNE=1 \
    NGINX_ENTRYPOINT_QUIET_LOGS=1
COPY nginx/default.conf.template /etc/nginx/templates/default.conf.template
COPY public/ /usr/share/nginx/html/
USER 101
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO /dev/null http://127.0.0.1:8080/healthz || exit 1
# ENTRYPOINT (renders the template) and CMD (nginx in the foreground) come from the base image.
