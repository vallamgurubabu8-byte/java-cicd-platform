#!/usr/bin/env bash

set -u

echo "================================"
echo " Java CI/CD Platform Startup"
echo "================================"

start_container() {
    local name="$1"

    if ! docker inspect "$name" >/dev/null 2>&1; then
        echo "[WARN] Container $name does not exist."
        return
    fi

    local status
    status=$(docker inspect -f '{{.State.Status}}' "$name")

    if [[ "$status" == "running" ]]; then
        echo "[PASS] $name is already running."
    else
        echo "[INFO] Starting $name..."
        if docker start "$name" >/dev/null; then
            echo "[PASS] $name started."
        else
            echo "[FAIL] Could not start $name."
        fi
    fi
}

if ! docker info >/dev/null 2>&1; then
    echo "[FAIL] Docker daemon is unavailable."
    echo "Start Docker Desktop and run this script again."
    exit 1
fi

start_container "local-registry"
start_container "jenkins"

echo
echo "---------- Service Checks ----------"

for i in {1..12}; do
    if curl -fsS http://localhost:8081/login >/dev/null 2>&1; then
        echo "[PASS] Jenkins is ready."
        break
    fi
    sleep 5
done

curl -fsS http://localhost:8081/login >/dev/null 2>&1 \
    || echo "[WARN] Jenkins is not responding yet."

for i in {1..6}; do
    if curl -sS --max-time 3 http://localhost:5000/v2/ \
        -o /dev/null; then
        echo "[PASS] Docker Registry is reachable."
        break
    fi
    sleep 2
done

echo
echo "---------- Kubernetes ----------"

if kubectl get nodes --request-timeout=5s >/dev/null 2>&1; then
    echo "[PASS] Kubernetes cluster is available."
    kubectl get nodes
else
    echo "[WARN] Kubernetes is unavailable."
    echo "Enable Kubernetes in Docker Desktop."
fi

echo
echo "Startup checks completed."
