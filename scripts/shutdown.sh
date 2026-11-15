#!/usr/bin/env bash

set -u

echo "================================"
echo " Java CI/CD Platform Shutdown"
echo "================================"

stop_container() {
    local name="$1"

    if ! docker inspect "$name" >/dev/null 2>&1; then
        echo "[WARN] $name container does not exist."
        return
    fi

    local status
    status=$(docker inspect -f '{{.State.Status}}' "$name")

    if [[ "$status" != "running" ]]; then
        echo "[PASS] $name is already stopped."
    else
        echo "[INFO] Stopping $name gracefully..."

        if docker stop --time 30 "$name" >/dev/null; then
            echo "[PASS] $name stopped."
        else
            echo "[FAIL] Could not stop $name."
        fi
    fi
}

if ! docker info >/dev/null 2>&1; then
    echo "[FAIL] Docker daemon is unavailable."
    exit 1
fi

echo
echo "---------- Stopping Services ----------"

stop_container "jenkins"
stop_container "local-registry"

echo
echo "---------- Remaining Containers ----------"

docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo
echo "Shutdown completed."
echo "Kubernetes workloads have NOT been stopped."
echo "No persistent data has been deleted."
