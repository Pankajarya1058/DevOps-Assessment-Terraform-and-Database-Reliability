#!/usr/bin/env bash
#
# scripts/restore.sh — restore a backup into a FRESH local database.
#
# "Fresh" here means a brand-new, isolated MySQL container with its own
# new volume - never the existing dev container from `docker compose up`.
# That's deliberate: the whole point of this script is to prove the
# backup file alone is enough to rebuild the database from nothing, the
# same way you'd have to during a real disaster recovery. Restoring into
# the dev container (which already has data / already ran the init/
# scripts) would prove nothing.
#
# Usage:
#   ./scripts/restore.sh                          # restores backups/LATEST
#   ./scripts/restore.sh backups/some_dump.sql.gz  # restores a specific file
#   ./scripts/restore.sh --cleanup                 # tear down the restore
#                                                     container afterward
#                                                     instead of leaving it
#                                                     up for inspection
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BACKUP_DIR="${PROJECT_ROOT}/backups"
RESTORE_CONTAINER="hotel-bookings-mysql-restore-verify"
RESTORE_VOLUME="hotel-bookings-mysql-restore-verify-data"
RESTORE_PORT="3307" # deliberately NOT 3306 - never collide with the dev container
CLEANUP_AFTER=false
BACKUP_FILE=""

cd "${PROJECT_ROOT}"

for arg in "$@"; do
  case "${arg}" in
    --cleanup)
      CLEANUP_AFTER=true
      ;;
    *)
      BACKUP_FILE="${arg}"
      ;;
  esac
done

if [[ ! -f .env ]]; then
  echo "ERROR: .env not found in ${PROJECT_ROOT} - can't read DB credentials." >&2
  exit 1
fi
# shellcheck disable=SC1091
source .env
: "${MYSQL_ROOT_PASSWORD:?MYSQL_ROOT_PASSWORD not set in .env}"

if [[ -z "${BACKUP_FILE}" ]]; then
  if [[ ! -f "${BACKUP_DIR}/LATEST" ]]; then
    echo "ERROR: no backup file given and ${BACKUP_DIR}/LATEST doesn't exist." >&2
    echo "       Run ./scripts/backup.sh first, or pass a file explicitly." >&2
    exit 1
  fi
  BACKUP_FILE="${BACKUP_DIR}/$(cat "${BACKUP_DIR}/LATEST")"
fi

if [[ ! -f "${BACKUP_FILE}" ]]; then
  echo "ERROR: backup file not found: ${BACKUP_FILE}" >&2
  exit 1
fi

META_FILE="${BACKUP_FILE%.sql.gz}.meta"

echo "==> Restoring from: ${BACKUP_FILE}"
echo "==> Target: a brand-new container '${RESTORE_CONTAINER}' on port ${RESTORE_PORT}"
echo "    (your regular dev container on port 3306 is left untouched)"
echo ""

echo "==> Removing any previous restore-verification container/volume..."
docker rm -f "${RESTORE_CONTAINER}" >/dev/null 2>&1 || true
docker volume rm -f "${RESTORE_VOLUME}" >/dev/null 2>&1 || true

echo "==> Starting a fresh MySQL container..."
docker run -d \
  --name "${RESTORE_CONTAINER}" \
  -e MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD}" \
  -p "${RESTORE_PORT}:3306" \
  -v "${RESTORE_VOLUME}:/var/lib/mysql" \
  mysql:8.0 >/dev/null

echo "==> Waiting for it to become ready..."
READY=false
for _ in $(seq 1 30); do
  if docker exec "${RESTORE_CONTAINER}" \
      mysqladmin ping -h localhost -u root -p"${MYSQL_ROOT_PASSWORD}" --silent 2>/dev/null; then
    READY=true
    break
  fi
  sleep 2
done

if [[ "${READY}" != "true" ]]; then
  echo "ERROR: restore container never became ready. Logs:" >&2
  docker logs "${RESTORE_CONTAINER}" 2>&1 | tail -50 >&2
  exit 1
fi

echo "==> Loading dump into the fresh container..."
gunzip -c "${BACKUP_FILE}" | docker exec -i "${RESTORE_CONTAINER}" \
  mysql -u root -p"${MYSQL_ROOT_PASSWORD}"

echo "==> Restore command finished. Verifying..."

# The dump's own `CREATE DATABASE` / `USE` statements determine the DB
# name inside the restored instance - read it back rather than assuming.
RESTORED_DB="$(docker exec "${RESTORE_CONTAINER}" \
  mysql -N -u root -p"${MYSQL_ROOT_PASSWORD}" \
  -e "SHOW DATABASES;" | grep -v -E '^(information_schema|mysql|performance_schema|sys)$' | head -1)"

if [[ -z "${RESTORED_DB}" ]]; then
  echo "FAIL: no application database found after restore." >&2
  exit 1
fi

BOOKINGS_COUNT="$(docker exec "${RESTORE_CONTAINER}" \
  mysql -N -u root -p"${MYSQL_ROOT_PASSWORD}" "${RESTORED_DB}" \
  -e "SELECT COUNT(*) FROM hotel_bookings;" 2>/dev/null || echo "ERROR")"
EVENTS_COUNT="$(docker exec "${RESTORE_CONTAINER}" \
  mysql -N -u root -p"${MYSQL_ROOT_PASSWORD}" "${RESTORED_DB}" \
  -e "SELECT COUNT(*) FROM booking_events;" 2>/dev/null || echo "ERROR")"

echo ""
echo "==> Restored database: ${RESTORED_DB}"
echo "    hotel_bookings:  ${BOOKINGS_COUNT} rows"
echo "    booking_events:  ${EVENTS_COUNT} rows"

PASS=true
if [[ "${BOOKINGS_COUNT}" == "ERROR" || "${EVENTS_COUNT}" == "ERROR" ]]; then
  echo "FAIL: could not query one or both tables after restore." >&2
  PASS=false
elif [[ -f "${META_FILE}" ]]; then
  EXPECTED_BOOKINGS="$(grep '^hotel_bookings_count=' "${META_FILE}" | cut -d= -f2)"
  EXPECTED_EVENTS="$(grep '^booking_events_count=' "${META_FILE}" | cut -d= -f2)"
  echo ""
  echo "==> Comparing against counts recorded at backup time (${META_FILE}):"
  echo "    hotel_bookings:  expected ${EXPECTED_BOOKINGS}, got ${BOOKINGS_COUNT}"
  echo "    booking_events:  expected ${EXPECTED_EVENTS}, got ${EVENTS_COUNT}"
  if [[ "${BOOKINGS_COUNT}" != "${EXPECTED_BOOKINGS}" || "${EVENTS_COUNT}" != "${EXPECTED_EVENTS}" ]]; then
    echo "FAIL: row counts don't match the backup's recorded metadata." >&2
    PASS=false
  fi
else
  echo ""
  echo "    (no .meta file found alongside this backup - skipping count comparison;"
  echo "     row counts above are simply what was restored, unverified against a baseline)"
fi

if [[ "${PASS}" != "true" ]]; then
  echo ""
  echo "==> RESTORE VERIFICATION: FAILED" >&2
  if [[ "${CLEANUP_AFTER}" == "true" ]]; then
    docker rm -f "${RESTORE_CONTAINER}" >/dev/null 2>&1 || true
    docker volume rm -f "${RESTORE_VOLUME}" >/dev/null 2>&1 || true
  fi
  exit 1
fi

echo ""
echo "==> RESTORE VERIFICATION: PASSED"

if [[ "${CLEANUP_AFTER}" == "true" ]]; then
  echo "==> --cleanup passed, tearing down the restore-verification container/volume..."
  docker rm -f "${RESTORE_CONTAINER}" >/dev/null 2>&1 || true
  docker volume rm -f "${RESTORE_VOLUME}" >/dev/null 2>&1 || true
else
  echo ""
  echo "    The restored instance is left running for manual inspection:"
  echo "      mysql -h 127.0.0.1 -P ${RESTORE_PORT} -u root -p${MYSQL_ROOT_PASSWORD} ${RESTORED_DB}"
  echo ""
  echo "    Tear it down when you're done:"
  echo "      docker rm -f ${RESTORE_CONTAINER} && docker volume rm ${RESTORE_VOLUME}"
fi
