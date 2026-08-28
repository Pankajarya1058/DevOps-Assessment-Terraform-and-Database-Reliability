#!/usr/bin/env bash
#
# scripts/backup.sh — create a timestamped dump of the running MySQL
# container's database.
#
# Usage:
#   ./scripts/backup.sh
#
# Reads DB name/credentials from .env in the project root. Writes:
#   backups/<db>_<UTC timestamp>.sql.gz   - the compressed dump
#   backups/<db>_<UTC timestamp>.meta     - row counts captured at dump time
#   backups/LATEST                        - plain text pointer to the most
#                                            recent dump filename, so
#                                            restore.sh can default to it
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BACKUP_DIR="${PROJECT_ROOT}/backups"
CONTAINER_NAME="hotel-bookings-mysql"

cd "${PROJECT_ROOT}"

if [[ ! -f .env ]]; then
  echo "ERROR: .env not found in ${PROJECT_ROOT} - can't read DB credentials." >&2
  exit 1
fi
# shellcheck disable=SC1091
source .env

: "${MYSQL_DATABASE:?MYSQL_DATABASE not set in .env}"
: "${MYSQL_ROOT_PASSWORD:?MYSQL_ROOT_PASSWORD not set in .env}"

mkdir -p "${BACKUP_DIR}"

echo "==> Checking that ${CONTAINER_NAME} is up and healthy..."
if ! docker inspect "${CONTAINER_NAME}" >/dev/null 2>&1; then
  echo "ERROR: container '${CONTAINER_NAME}' does not exist. Run 'docker compose up -d' first." >&2
  exit 1
fi

HEALTH="$(docker inspect --format='{{.State.Health.Status}}' "${CONTAINER_NAME}" 2>/dev/null || echo "unknown")"
if [[ "${HEALTH}" != "healthy" ]]; then
  echo "ERROR: container '${CONTAINER_NAME}' is not healthy (status: ${HEALTH})." >&2
  echo "       Run 'docker compose ps' / 'docker compose logs mysql' to investigate." >&2
  exit 1
fi

TIMESTAMP="$(date -u +"%Y%m%dT%H%M%SZ")"
BASENAME="${MYSQL_DATABASE}_${TIMESTAMP}"
DUMP_FILE="${BACKUP_DIR}/${BASENAME}.sql.gz"
META_FILE="${BACKUP_DIR}/${BASENAME}.meta"

echo "==> Dumping database '${MYSQL_DATABASE}' from ${CONTAINER_NAME}..."
# --single-transaction: consistent snapshot for InnoDB without locking
#   writers for the duration of the dump.
# --routines --triggers: this schema has neither today, but a backup
#   script that silently drops them the day someone adds one is a bad
#   surprise - safe to always include.
# --databases <name>: emits CREATE DATABASE/USE statements, so the dump
#   is self-contained and can be restored into a database that doesn't
#   exist yet (see restore.sh).
docker exec "${CONTAINER_NAME}" \
  mysqldump \
    -u root \
    -p"${MYSQL_ROOT_PASSWORD}" \
    --single-transaction \
    --routines \
    --triggers \
    --databases "${MYSQL_DATABASE}" \
  | gzip -9 > "${DUMP_FILE}"

if [[ ! -s "${DUMP_FILE}" ]]; then
  echo "ERROR: dump file is empty - something went wrong. Check the output above." >&2
  rm -f "${DUMP_FILE}"
  exit 1
fi

echo "==> Recording row counts for later verification..."
BOOKINGS_COUNT="$(docker exec "${CONTAINER_NAME}" \
  mysql -N -u root -p"${MYSQL_ROOT_PASSWORD}" "${MYSQL_DATABASE}" \
  -e "SELECT COUNT(*) FROM hotel_bookings;")"
EVENTS_COUNT="$(docker exec "${CONTAINER_NAME}" \
  mysql -N -u root -p"${MYSQL_ROOT_PASSWORD}" "${MYSQL_DATABASE}" \
  -e "SELECT COUNT(*) FROM booking_events;")"

cat > "${META_FILE}" <<EOF
database=${MYSQL_DATABASE}
dumped_at_utc=${TIMESTAMP}
dump_file=${BASENAME}.sql.gz
hotel_bookings_count=${BOOKINGS_COUNT}
booking_events_count=${EVENTS_COUNT}
EOF

echo "${BASENAME}.sql.gz" > "${BACKUP_DIR}/LATEST"

DUMP_SIZE="$(du -h "${DUMP_FILE}" | cut -f1)"

echo ""
echo "==> Backup complete."
echo "    File:            ${DUMP_FILE} (${DUMP_SIZE})"
echo "    Metadata:        ${META_FILE}"
echo "    hotel_bookings:  ${BOOKINGS_COUNT} rows"
echo "    booking_events:  ${EVENTS_COUNT} rows"
echo ""
echo "    Restore with:    ./scripts/restore.sh"
echo "    (defaults to this file, via backups/LATEST)"
