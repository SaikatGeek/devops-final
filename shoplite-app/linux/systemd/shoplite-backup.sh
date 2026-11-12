#!/bin/sh
# One pg_dump of the ShopLite database (question 3.3), run by shoplite-backup.service.
# Installed as /usr/local/bin/shoplite-backup.
#
# Postgres runs in the Docker Compose stack (project "shoplite") and is not published on
# the host, so pg_dump runs inside the postgres container and its output is written to a
# file here. The container's own POSTGRES_USER and POSTGRES_DB are used, so nothing is
# hard-coded.
set -eu
umask 077  # a backup holds every order: readable by root only

BACKUP_DIR=/var/backups/shoplite
target="$BACKUP_DIR/shoplite-$(date +%Y%m%d-%H%M%S).sql"
partial="$target.partial"
trap 'rm -f "$partial"' EXIT  # a failed dump leaves no half-written file behind

mkdir -p "$BACKUP_DIR"
docker compose -p shoplite exec -T postgres \
  sh -c 'exec pg_dump --username "$POSTGRES_USER" --dbname "$POSTGRES_DB"' >"$partial"
mv "$partial" "$target"
echo "backup written: $target ($(stat -c %s "$target") bytes)"
