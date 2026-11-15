#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATOR="$PROJECT_ROOT/scripts/validate-config.py"

CONFIG_FILE="${1:-$PROJECT_ROOT/project-configs/medical-appointment.yaml}"

echo "========================================"
echo " Java CI/CD Configuration Validation"
echo "========================================"

if [[ ! -f "$VALIDATOR" ]]; then
    echo "[ERROR] Python validator not found: $VALIDATOR"
    exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "[ERROR] Configuration file not found: $CONFIG_FILE"
    exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "[ERROR] Python3 is not installed."
    exit 1
fi

echo "[INFO] Validating configuration:"
echo "$CONFIG_FILE"
echo

python3 "$VALIDATOR" --config "$CONFIG_FILE"

echo
echo "[PASS] Configuration validation completed."
