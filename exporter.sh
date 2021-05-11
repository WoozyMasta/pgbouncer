#!/bin/sh

set -eu

con="${POSTGRES_USER:-postgres}"
con="$con:${POSTGRES_PASSWORD:-postgres}"
con="$con@${POSTGRES_HOST:-localhost}"
con="$con:${POSTGRES_PORT:-5432}"

exec /pgbouncer_exporter \
  --pgBouncer.connectionString="postgres://$con/pgbouncer?sslmode=disable" \
  --web.listen-address="${LISTEN_ADDRESS:-:9127}" \
  --web.telemetry-path="${TELEMETRY_PATH:-/metrics}" \
  --log.level="${LOG_LEVEL:-info}" \
  --log.format="${LOG_FORMAT:-logfmt}"
