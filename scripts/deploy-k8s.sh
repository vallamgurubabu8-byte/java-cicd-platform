#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${1:-$PROJECT_ROOT/project-configs/medical-appointment.yaml}"

LOCAL_REGISTRY="${LOCAL_REGISTRY:-localhost:5000}"
K8S_REGISTRY="${K8S_REGISTRY:-host.docker.internal:5000}"
IMAGE_TAG="${IMAGE_TAG:-}"

echo "========================================"
echo " Java CI/CD Kubernetes Deployment"
echo "========================================"

"$PROJECT_ROOT/scripts/validate-config.sh" "$CONFIG_FILE"

read_config() {
    python3 -c "$1" "$CONFIG_FILE"
}

NAMESPACE="$(read_config 'import sys,yaml; print(yaml.safe_load(open(sys.argv[1]))["deployment"]["namespace"])')"
DEPLOYMENT="$(read_config 'import sys,yaml; print(yaml.safe_load(open(sys.argv[1]))["deployment"]["name"])')"
CONTAINER="$(read_config 'import sys,yaml; print(yaml.safe_load(open(sys.argv[1]))["deployment"]["containerName"])')"
SERVICE="$(read_config 'import sys,yaml; print(yaml.safe_load(open(sys.argv[1]))["deployment"]["serviceName"])')"
IMAGE_NAME="$(read_config 'import sys,yaml; print(yaml.safe_load(open(sys.argv[1]))["container"]["imageName"])')"

if [[ -z "$IMAGE_TAG" ]]; then
    echo "[ERROR] IMAGE_TAG is required."
    echo "Example: IMAGE_TAG=build-20261115122858 ./scripts/deploy-k8s.sh"
    exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
    echo "[ERROR] kubectl is not installed."
    exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
    echo "[ERROR] Docker is not installed."
    exit 1
fi

if ! kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
    echo "[ERROR] Kubernetes namespace not found: $NAMESPACE"
    exit 1
fi

if ! kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" >/dev/null 2>&1; then
    echo "[ERROR] Target Deployment not found: $DEPLOYMENT"
    exit 1
fi

if ! kubectl get service "$SERVICE" -n "$NAMESPACE" >/dev/null 2>&1; then
    echo "[ERROR] Target Service not found: $SERVICE"
    exit 1
fi

CONTAINERS="$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
    -o jsonpath='{.spec.template.spec.containers[*].name}')"

if [[ " $CONTAINERS " != *" $CONTAINER "* ]]; then
    echo "[ERROR] Container $CONTAINER not found in Deployment $DEPLOYMENT"
    exit 1
fi

LOCAL_IMAGE="$LOCAL_REGISTRY/$IMAGE_NAME:$IMAGE_TAG"
K8S_IMAGE="$K8S_REGISTRY/$IMAGE_NAME:$IMAGE_TAG"

if ! docker image inspect "$LOCAL_IMAGE" >/dev/null 2>&1; then
    echo "[ERROR] Local image not found: $LOCAL_IMAGE"
    echo "[INFO] Build and push the image before deployment."
    exit 1
fi

echo "[INFO] Namespace: $NAMESPACE"
echo "[INFO] Deployment: $DEPLOYMENT"
echo "[INFO] Service: $SERVICE"
echo "[INFO] Container: $CONTAINER"
echo "[INFO] Image: $K8S_IMAGE"

echo
echo "[INFO] Updating Deployment image..."

kubectl set image "deployment/$DEPLOYMENT" \
    "$CONTAINER=$K8S_IMAGE" \
    -n "$NAMESPACE"

echo
echo "[INFO] Waiting for rollout..."

kubectl rollout status "deployment/$DEPLOYMENT" \
    -n "$NAMESPACE" \
    --timeout=180s

echo
echo "[PASS] Kubernetes deployment completed successfully."

kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE"
kubectl get pods -n "$NAMESPACE" \
    -l "app=$DEPLOYMENT"
