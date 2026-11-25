#!/bin/sh
# Daily Neon → local Postgres backup (#323).
#
# Each run:
#   1. pg_dump the public schema from Neon (direct endpoint) to a timestamped file
#   2. restore it into the local backup Postgres (fresh public schema every time)
#   3. verify per-table row counts match exactly between Neon and the local copy
#      (one retry after 60s on any failure)
#   4. rotate dump files, keeping the newest $KEEP_DUMPS
#   5. record success time (read by the container healthcheck)
#
# Runs once at container start, then daily at $BACKUP_HOUR_UTC.
# Usage inside the container: backup.sh          → scheduler loop
#                             backup.sh --once   → single run, exit code = result
set -u

: "${SOURCE_URL:?SOURCE_URL must be set (Neon direct endpoint, postgresql://...?sslmode=require)}"
: "${BACKUP_DB_PASSWORD:?BACKUP_DB_PASSWORD must be set}"
BACKUP_DIR=/backups
KEEP_DUMPS="${KEEP_DUMPS:-14}"
BACKUP_HOUR_UTC="${BACKUP_HOUR_UTC:-8}"
LOKI_URL="${LOKI_URL:-}"
LOCAL_URL="postgresql://backup:${BACKUP_DB_PASSWORD}@backup-db:5432/poketeamdex"

log() {
  level="$1"; shift
  line="ts=$(date -u +%Y-%m-%dT%H:%M:%SZ) level=$level job=neon-backup msg=\"$*\""
  echo "$line"
  if [ -n "$LOKI_URL" ]; then
    # Same label scheme as the API's direct Loki pushes (app/core/logging.py).
    esc=$(printf '%s' "$line" | sed 's/\\/\\\\/g; s/"/\\"/g')
    curl -s -m 5 -o /dev/null -H 'Content-Type: application/json' \
      -X POST "${LOKI_URL%/}/loki/api/v1/push" \
      -d "{\"streams\":[{\"stream\":{\"job\":\"server\",\"source\":\"direct\",\"app\":\"poketeamdex_backup\",\"level\":\"$level\"},\"values\":[[\"$(date +%s)000000000\",\"$esc\"]]}]}" \
      || true
  fi
}

COUNT_SQL="SELECT table_name, (xpath('/row/c/text()', query_to_xml(format('SELECT count(*) AS c FROM public.%I', table_name), false, true, '')))[1]::text::int FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE' ORDER BY 1;"

run_once() {
  ts=$(date -u +%Y%m%dT%H%M%SZ)
  dump="$BACKUP_DIR/poketeamdex-$ts.dump"
  log INFO "backup started"

  # 1. Dump. Write to .partial first so a failed dump never counts as a backup.
  pg_dump -Fc -n public --no-owner --no-acl -d "$SOURCE_URL" -f "$dump.partial" || { log ERROR "pg_dump from Neon failed"; return 1; }
  mv "$dump.partial" "$dump" || return 1

  # 2. Restore into a fresh public schema (the dump recreates it).
  psql -q -v ON_ERROR_STOP=1 -d "$LOCAL_URL" -c 'DROP SCHEMA IF EXISTS public CASCADE;' || { log ERROR "could not reset local schema"; return 1; }
  pg_restore --no-owner --no-acl --exit-on-error -d "$LOCAL_URL" "$dump" || { log ERROR "pg_restore into local Postgres failed"; return 1; }

  # 3. Verify: per-table row counts must match exactly. A write to Neon between the
  #    dump and the count can cause a one-off mismatch; attempt() retries once.
  psql -At -v ON_ERROR_STOP=1 -d "$SOURCE_URL" -c "$COUNT_SQL" > /tmp/src_counts || { log ERROR "row count on Neon failed"; return 1; }
  psql -At -v ON_ERROR_STOP=1 -d "$LOCAL_URL" -c "$COUNT_SQL" > /tmp/dst_counts || { log ERROR "row count on local failed"; return 1; }
  if [ ! -s /tmp/src_counts ] || [ "$(cat /tmp/src_counts)" != "$(cat /tmp/dst_counts)" ]; then
    log ERROR "verification failed: neon=[$(tr '\n' ' ' < /tmp/src_counts)] local=[$(tr '\n' ' ' < /tmp/dst_counts)]"
    return 1
  fi

  # 4. Rotate.
  ls -1t "$BACKUP_DIR"/poketeamdex-*.dump | tail -n +"$((KEEP_DUMPS + 1))" | xargs -r rm --
  rm -f "$BACKUP_DIR"/*.partial

  # 5. Record success.
  date +%s > "$BACKUP_DIR/.last_success" || return 1
  size=$(du -h "$dump" | cut -f1)
  log INFO "backup succeeded file=$(basename "$dump") size=$size tables=[$(tr '\n' ' ' < /tmp/dst_counts)]"
}

seconds_until_next_run() {
  now=$(date -u +%s)
  target=$(date -u -d "today ${BACKUP_HOUR_UTC}:00" +%s)
  [ "$target" -le "$now" ] && target=$((target + 86400))
  echo $((target - now))
}

attempt() {
  # Every step in run_once checks its own exit status: `set -e` is ignored inside
  # functions called from `||`/`if`, so it can't be relied on here.
  run_once && return 0
  log WARN "backup attempt failed; retrying in 60s"
  sleep 60
  run_once || { log ERROR "backup failed after retry"; return 1; }
}

if [ "${1:-}" = "--once" ]; then
  attempt
  exit $?
fi

while true; do
  attempt || true
  wait_s=$(seconds_until_next_run)
  log INFO "next backup in ${wait_s}s (daily at ${BACKUP_HOUR_UTC}:00 UTC)"
  sleep "$wait_s"
done
