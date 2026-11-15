#!/usr/bin/env bash
set -Eeuo pipefail

DAYS="${DAYS:-7}"
MODE="dry-run"

usage() {
    echo "Usage: $0 [--dry-run | --execute]"
    echo "Environment: DAYS=7 (minimum image age in days)"
}

case "${1:---dry-run}" in
    --dry-run) MODE="dry-run" ;;
    --execute) MODE="execute" ;;
    --help|-h) usage; exit 0 ;;
    *) usage; exit 1 ;;
esac

[[ "$DAYS" =~ ^[0-9]+$ ]] || {
    echo "[FAIL] DAYS must be a non-negative integer."
    exit 1
}

command -v docker >/dev/null 2>&1 || {
    echo "[FAIL] Docker is not installed."
    exit 1
}

docker info >/dev/null 2>&1 || {
    echo "[FAIL] Docker daemon is not reachable."
    exit 1
}

echo "================================"
echo " Docker Image Cleanup"
echo "================================"
echo "[INFO] Mode: $MODE"
echo "[INFO] Minimum image age: $DAYS days"

# Collect images used by running containers.
declare -A IN_USE=()

while IFS= read -r image_id; do
    [[ -n "$image_id" ]] && IN_USE["$image_id"]=1
done < <(docker ps -q | xargs -r docker inspect \
    --format '{{.Image}}' 2>/dev/null || true)

# Collect Kubernetes workload images from all namespaces.
if command -v kubectl >/dev/null 2>&1 &&
   kubectl cluster-info >/dev/null 2>&1; then
    while IFS= read -r image; do
        [[ -n "$image" ]] || continue
        image_id="$(docker image inspect --format '{{.Id}}' "$image" 2>/dev/null || true)"
        [[ -n "$image_id" ]] && IN_USE["$image_id"]=1
    done < <(
        kubectl get pods --all-namespaces \
            -o jsonpath='{range .items[*].status.containerStatuses[*]}{.image}{"\n"}{end}' \
            2>/dev/null || true
    )
else
    echo "[WARN] Kubernetes is unavailable; only running Docker containers will be protected."
fi

CANDIDATES=0
DELETED=0

# List dangling images older than the configured age.
while IFS= read -r image_id; do
    [[ -n "$image_id" ]] || continue

    created="$(docker image inspect --format '{{.Created}}' "$image_id")"
    created_epoch="$(date -d "$created" +%s)"
    cutoff_epoch="$(date -d "$DAYS days ago" +%s)"

    (( created_epoch <= cutoff_epoch )) || continue

    if [[ -n "${IN_USE[$image_id]:-}" ]]; then
        echo "[SKIP] In-use image: $image_id"
        continue
    fi

    CANDIDATES=$((CANDIDATES + 1))
    echo "[CANDIDATE] $image_id (created: $created)"

    if [[ "$MODE" == "execute" ]]; then
        if docker image rm "$image_id"; then
            DELETED=$((DELETED + 1))
            echo "[PASS] Removed: $image_id"
        else
            echo "[WARN] Could not remove: $image_id"
        fi
    fi
done < <(docker images --filter dangling=true --format '{{.ID}}' | sort -u)

echo "--------------------------------"
echo "[INFO] Candidates: $CANDIDATES"

if [[ "$MODE" == "dry-run" ]]; then
    echo "[INFO] No images were deleted."
    echo "[INFO] Review the candidates, then use --execute to remove them."
else
    echo "[INFO] Images removed: $DELETED"
fi

echo "[PASS] Cleanup scan completed."
