#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${1:-$PROJECT_ROOT/project-configs/medical-appointment.yaml}"
WORKSPACE="$PROJECT_ROOT/workspace"

REGISTRY="${REGISTRY:-localhost:5000}"
IMAGE_TAG="${IMAGE_TAG:-build-$(date +%Y%m%d%H%M%S)}"

echo "========================================"
echo " Docker Build and Push"
echo "========================================"

"$PROJECT_ROOT/scripts/validate-config.sh" "$CONFIG_FILE"

IMAGE_NAME="$(python3 -c 'import sys,yaml; print(yaml.safe_load(open(sys.argv[1]))["container"]["imageName"])' "$CONFIG_FILE")"
DOCKERFILE="$(python3 -c 'import sys,yaml; print(yaml.safe_load(open(sys.argv[1]))["container"].get("dockerfile", "Dockerfile"))' "$CONFIG_FILE")"

APP_DIR="$WORKSPACE"
DOCKERFILE_PATH="$APP_DIR/$DOCKERFILE"

if ! command -v docker >/dev/null 2>&1; then
    echo "[ERROR] Docker is not installed."
    exit 1
fi

if [[ ! -d "$APP_DIR/.git" ]]; then
    echo "[ERROR] Application workspace not found. Run build-local.sh first."
    exit 1
fi

if [[ ! -f "$DOCKERFILE_PATH" ]]; then
    echo "[ERROR] Dockerfile not found: $DOCKERFILE_PATH"
    exit 1
fi

JAR_COUNT="$(find "$APP_DIR/target" -maxdepth 1 -type f -name '*.jar' ! -name '*.original' | wc -l)"

if [[ "$JAR_COUNT" -eq 0 ]]; then
    echo "[ERROR] No executable JAR found. Run build-local.sh first."
    exit 1
fi

FULL_IMAGE="$REGISTRY/$IMAGE_NAME:$IMAGE_TAG"

echo "[INFO] Building image: $FULL_IMAGE"

docker build \
    -f "$DOCKERFILE_PATH" \
    -t "$FULL_IMAGE" \
    "$APP_DIR"

echo "[INFO] Pushing image to registry..."
docker push "$FULL_IMAGE"

echo
echo "[PASS] Docker image built and pushed successfully."
echo "[INFO] Image: $FULL_IMAGE"
