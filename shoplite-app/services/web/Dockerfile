# syntax=docker/dockerfile:1

ARG NGINX_IMAGE=nginxinc/nginx-unprivileged:1.30.6-alpine

# Three stages: `base` patches the base image, and the test files (fake API, checks) exist only
# in `test`, never in `runtime`. Both build on `base`, so the tests run the nginx that ships.

# ---- base: the base image with the security fixes it does not have yet ----
FROM ${NGINX_IMAGE} AS base
# The pipeline's Trivy gate (question 7a) stops on CRITICAL vulnerabilities, and no build of the
# base image has these fixes yet. Remove each line once the base image has its fix.
# - brotli-libs 1.2.0-r1: an out-of-bounds write (CVE-2026-111497), fixed in 1.2.1-r0.
# - nginx 1.30.6: use-after-free and HTTP/2 flaws (CVE-2026-113425, CVE-2026-121810,
#   CVE-2026-123007, CVE-2026-123633), fixed in 1.30.7. It comes from nginx.org's own Alpine
#   repository, like the base image's 1.30.6 (its signing key is already in the image), with the
#   base image's modules at the same version, because each module requires its exact nginx.
USER 0
RUN apk add --no-cache brotli-libs=1.2.1-r0 \
 && apk add --no-cache --repository https://nginx.org/packages/alpine/v3.24/main \
      nginx=1.30.7-r1 nginx-module-geoip=1.30.7-r1 nginx-module-image-filter=1.30.7-r1 \
      nginx-module-njs=1.30.7.1.0.2-r1 nginx-module-xslt=1.30.7-r1
USER 101

# ---- test: the runtime setup plus a fake API; `docker build --target test` then run it ----
FROM base AS test
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
FROM base AS runtime
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
EXPOSE 8080
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
  CMD ["wget", "-qO", "/dev/null", "http://127.0.0.1:8080/healthz"]
# ENTRYPOINT (renders the template) and CMD (nginx in the foreground) come from the base image.
