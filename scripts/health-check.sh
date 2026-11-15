#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${1:-$PROJECT_ROOT/project-configs/medical-appointment.yaml}"

echo "========================================"
echo " Java CI/CD Health Check"
echo "========================================"

"$PROJECT_ROOT/scripts/validate-config.sh" "$CONFIG_FILE"

read_config() {
    python3 -c "$1" "$CONFIG_FILE"
}

NAMESPACE="$(read_config 'import sys,yaml; print(yaml.safe_load(open(sys.argv[1]))["deployment"]["namespace"])')"
DEPLOYMENT="$(read_config 'import sys,yaml; print(yaml.safe_load(open(sys.argv[1]))["deployment"]["name"])')"
SERVICE="$(read_config 'import sys,yaml; print(yaml.safe_load(open(sys.argv[1]))["deployment"]["serviceName"])')"
EXPECTED_REPLICAS="$(read_config 'import sys,yaml; print(yaml.safe_load(open(sys.argv[1]))["deployment"]["replicas"])')"

PASS=0
FAIL=0

check() {
    local description="$1"
    shift

    echo
    echo "[CHECK] $description"

    if "$@"; then
        echo "[PASS] $description"
        PASS=$((PASS + 1))
    else
        echo "[FAIL] $description"
        FAIL=$((FAIL + 1))
    fi
}

check_deployment() {
    local ready
    ready="$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
        -o jsonpath='{.status.readyReplicas}')"
    [[ "${ready:-0}" == "$EXPECTED_REPLICAS" ]]
}

check_pods() {
    local ready_count
    ready_count="$(kubectl get pods -n "$NAMESPACE" \
        -l "app=$DEPLOYMENT" \
        -o jsonpath='{range .items[*]}{.status.containerStatuses[0].ready}{"\n"}{end}' |
        grep -c '^true$' || true)"

    [[ "$ready_count" -eq "$EXPECTED_REPLICAS" ]]
}

check_service() {
    kubectl get service "$SERVICE" -n "$NAMESPACE" >/dev/null
}

check_rollout() {
    kubectl rollout status "deployment/$DEPLOYMENT" \
        -n "$NAMESPACE" --timeout=30s >/dev/null
}


SERVICE_PORT="$(read_config 'import sys,yaml; print(yaml.safe_load(open(sys.argv[1]))["deployment"]["servicePort"])')"

check_http() {
    local local_port=18081
    local health_path="${HEALTH_PATH:-/appointments/getbystatus}"
    local url="http://127.0.0.1:$local_port$health_path"

    kubectl port-forward \
        --address 127.0.0.1 \
        "service/$SERVICE" \
        "$local_port:$SERVICE_PORT" \
        -n "$NAMESPACE" >/tmp/java-cicd-port-forward.log 2>&1 &

    local pf_pid=$!
    local ready=false

    for attempt in {1..15}; do
        if curl -sS --max-time 2 "$url" -o /dev/null 2>/dev/null; then
            ready=true
            break
        fi
        sleep 1
    done

    if [[ "$ready" != "true" ]]; then
        kill "$pf_pid" 2>/dev/null || true
        wait "$pf_pid" 2>/dev/null || true
        echo "[ERROR] Application endpoint did not respond."
        return 1
    fi

    local http_code
    http_code="$(curl -sS -o /dev/null -w '%{http_code}' \
        --max-time 10 "$url")"

    kill "$pf_pid" 2>/dev/null || true
    wait "$pf_pid" 2>/dev/null || true

    echo "[INFO] HTTP status: $http_code"
    [[ "$http_code" =~ ^2[0-9][0-9]$ ]]
}

check "Deployment readiness" check_deployment
check "Pod readiness" check_pods
check "Kubernetes Service" check_service
check "Deployment rollout" check_rollout
check "Application HTTP endpoint" check_http

echo
echo "========================================"
echo " Health Check Summary"
echo "========================================"
echo "PASS: $PASS"
echo "FAIL: $FAIL"

if [[ "$FAIL" -gt 0 ]]; then
    echo "[FAIL] Health checks detected problems."
    exit 1
fi

echo "[PASS] All health checks completed successfully."
