#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${1:-$PROJECT_ROOT/project-configs/medical-appointment.yaml}"
WORKSPACE="$PROJECT_ROOT/workspace"

echo "========================================"
echo " Java CI/CD Local Build"
echo "========================================"

"$PROJECT_ROOT/scripts/validate-config.sh" "$CONFIG_FILE"

REPOSITORY="$(python3 -c 'import sys,yaml; print(yaml.safe_load(open(sys.argv[1]))["project"]["repository"])' "$CONFIG_FILE")"
BRANCH="$(python3 -c 'import sys,yaml; print(yaml.safe_load(open(sys.argv[1]))["project"].get("defaultBranch", "main"))' "$CONFIG_FILE")"
BUILD_TOOL="$(python3 -c 'import sys,yaml; print(yaml.safe_load(open(sys.argv[1]))["build"]["tool"])' "$CONFIG_FILE")"
TEST_COMMAND="$(python3 -c 'import sys,yaml; print(yaml.safe_load(open(sys.argv[1]))["build"].get("testCommand", "verify"))' "$CONFIG_FILE")"

if [[ "$BUILD_TOOL" != "maven" ]]; then
    echo "[ERROR] Unsupported build tool: $BUILD_TOOL"
    exit 1
fi

command -v git >/dev/null || { echo "[ERROR] Git is not installed."; exit 1; }
command -v mvn >/dev/null || { echo "[ERROR] Maven is not installed."; exit 1; }

mkdir -p "$WORKSPACE"

if [[ -d "$WORKSPACE/.git" ]]; then
    echo "[INFO] Updating existing repository..."
    git -C "$WORKSPACE" fetch origin
    git -C "$WORKSPACE" checkout "$BRANCH"
    git -C "$WORKSPACE" pull --ff-only origin "$BRANCH"
else
    if [[ -e "$WORKSPACE" ]] && [[ -n "$(ls -A "$WORKSPACE")" ]]; then
        echo "[ERROR] Workspace exists but is not a Git repository."
        exit 1
    fi

    echo "[INFO] Cloning application repository..."
    git clone --branch "$BRANCH" "$REPOSITORY" "$WORKSPACE"
fi

echo "[INFO] Running Maven $TEST_COMMAND..."
cd "$WORKSPACE"
mvn "$TEST_COMMAND"

echo "[PASS] Local build completed successfully."
echo "[INFO] Generated JAR files:"
find "$WORKSPACE/target" -maxdepth 1 -type f -name '*.jar' -print
