#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="$ROOT_DIR/project-configs/medical-appointment.yaml"
BACKUP_DIR="$ROOT_DIR/backups/mysql"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

log() {
    echo "[$(date '+%H:%M:%S')] $*"
}

fail() {
    echo "[FAIL] $*" >&2
    exit 1
}

# Validate project configuration
python3 "$ROOT_DIR/scripts/validate-config.py" --config "$CONFIG" \
    || fail "Configuration validation failed."

# Read values from YAML configuration
read_config() {
    python3 - "$CONFIG" "$1" <<'PY'
import sys
import yaml

with open(sys.argv[1], encoding="utf-8") as file:
    config = yaml.safe_load(file)

value = config
for key in sys.argv[2].split("."):
    value = value[key]

print(value)
PY
}

NAMESPACE="$(read_config deployment.namespace)"
DB_NAME="$(read_config database.databaseName)"
BACKUP_FILE="$BACKUP_DIR/${DB_NAME}_${TIMESTAMP}.sql"
TEMP_FILE="${BACKUP_FILE}.tmp"

mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"
umask 077

cleanup() {
    [[ -f "$TEMP_FILE" ]] && rm -f "$TEMP_FILE"
}
trap cleanup EXIT

log "Namespace: $NAMESPACE"
log "Database: $DB_NAME"

# Check MySQL deployment
kubectl rollout status deployment/mysql \
    -n "$NAMESPACE" --timeout=60s \
    || fail "MySQL deployment is not ready."

# Find MySQL pod
POD="$(kubectl get pods -n "$NAMESPACE" \
    -l app=mysql \
    -o jsonpath='{.items[0].metadata.name}')"

[[ -n "$POD" ]] || fail "MySQL pod not found."

kubectl wait --for=condition=Ready "pod/$POD" \
    -n "$NAMESPACE" --timeout=60s \
    || fail "MySQL pod is not ready."

log "MySQL pod: $POD"
log "Starting database backup..."

# Run mysqldump inside the MySQL container.
# Password is read from the container environment, not printed.
kubectl exec -n "$NAMESPACE" "$POD" -c mysql -- \
    sh -c '
        test -n "$MYSQL_ROOT_PASSWORD" || exit 1
        command -v mysqldump >/dev/null 2>&1 || exit 1
        MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysqldump \
            --user=root \
            --single-transaction \
            --routines \
            --triggers \
            --events \
            --databases "$1"
    ' sh "$DB_NAME" > "$TEMP_FILE" \
    || fail "MySQL dump failed."

[[ -s "$TEMP_FILE" ]] || fail "Backup file is empty."

mv "$TEMP_FILE" "$BACKUP_FILE"
chmod 600 "$BACKUP_FILE"

log "[PASS] MySQL backup completed successfully."
log "Backup file: $BACKUP_FILE"
log "Backup size: $(du -h "$BACKUP_FILE" | cut -f1)"
