
#!/usr/bin/env bash

set -euo pipefail

# --------------------------------------------------
# Project configuration
# --------------------------------------------------

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${1:-$PROJECT_ROOT/project-configs/medical-appointment.yaml}"

echo "========================================"
echo " Java CI/CD Health Check"
echo "========================================"

# Validate project configuration
"$PROJECT_ROOT/scripts/validate-config.sh" "$CONFIG_FILE"

# Read values from YAML configuration
read_config() {
    python3 -c "$1" "$CONFIG_FILE"
}

NAMESPACE="$(read_config 'import sys,yaml; print(yaml.safe_load(open(sys.argv[1]))["deployment"]["namespace"])')"
DEPLOYMENT="$(read_config 'import sys,yaml; print(yaml.safe_load(open(sys.argv[1]))["deployment"]["name"])')"
SERVICE="$(read_config 'import sys,yaml; print(yaml.safe_load(open(sys.argv[1]))["deployment"]["serviceName"])')"
EXPECTED_REPLICAS="$(read_config 'import sys,yaml; print(yaml.safe_load(open(sys.argv[1]))["deployment"]["replicas"])')"
SERVICE_PORT="$(read_config 'import sys,yaml; print(yaml.safe_load(open(sys.argv[1]))["deployment"]["servicePort"])')"

# Health endpoint can be overridden using HEALTH_PATH
HEALTH_PATH="${HEALTH_PATH:-/actuator/health}"

PASS=0
FAIL=0

# --------------------------------------------------
# Generic check function
# --------------------------------------------------

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

# --------------------------------------------------
# 1. Deployment readiness
# --------------------------------------------------

check_deployment() {
    local ready

    ready="$(kubectl get deployment "$DEPLOYMENT" \
        -n "$NAMESPACE" \
        -o jsonpath='{.status.readyReplicas}')"

    [[ "${ready:-0}" == "$EXPECTED_REPLICAS" ]]
}

# --------------------------------------------------
# 2. Pod readiness
# --------------------------------------------------

check_pods() {
    local selector
    local ready_count

    # Read deployment selector dynamically
    selector="$(kubectl get deployment "$DEPLOYMENT" \
        -n "$NAMESPACE" \
        -o json | python3 -c '
import sys, json

deployment = json.load(sys.stdin)
labels = deployment["spec"]["selector"]["matchLabels"]

print(",".join(f"{key}={value}" for key, value in labels.items()))
')"

    if [[ -z "$selector" ]]; then
        echo "[ERROR] Could not determine deployment pod selector."
        return 1
    fi

    echo "[INFO] Pod selector: $selector"

    ready_count="$(kubectl get pods \
        -n "$NAMESPACE" \
        -l "$selector" \
        -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' |
        grep -c '^True$' || true)"

    echo "[INFO] Ready pods: $ready_count / $EXPECTED_REPLICAS"

    [[ "$ready_count" -eq "$EXPECTED_REPLICAS" ]]
}

# --------------------------------------------------
# 3. Kubernetes Service
# --------------------------------------------------

check_service() {
    kubectl get service "$SERVICE" \
        -n "$NAMESPACE" >/dev/null

    echo "[INFO] Service: $SERVICE"
}

# --------------------------------------------------
# 4. Deployment rollout
# --------------------------------------------------

check_rollout() {
    kubectl rollout status "deployment/$DEPLOYMENT" \
        -n "$NAMESPACE" \
        --timeout=60s
}

# --------------------------------------------------
# 5. Application HTTP health check
# --------------------------------------------------

check_http() {
    local local_port=18081
    local url="http://127.0.0.1:$local_port$HEALTH_PATH"
    local log_file="/tmp/java-cicd-port-forward.log"

    local pf_pid
    local ready=false
    local http_code

    echo "[INFO] Starting Kubernetes port-forward..."

    # Start port-forward in the background
    kubectl port-forward \
        --address 127.0.0.1 \
        "service/$SERVICE" \
        "$local_port:$SERVICE_PORT" \
        -n "$NAMESPACE" >"$log_file" 2>&1 &

    pf_pid=$!

    # Wait until the health endpoint responds
    for attempt in {1..20}; do

        if ! kill -0 "$pf_pid" 2>/dev/null; then
            echo "[ERROR] Port-forward process stopped."
            cat "$log_file"
            wait "$pf_pid" 2>/dev/null || true
            return 1
        fi

        if curl -fsS \
            --max-time 2 \
            "$url" >/dev/null 2>&1; then

            ready=true
            break
        fi

        sleep 1
    done

    # Stop port-forward and report failure
    if [[ "$ready" != "true" ]]; then
        echo "[ERROR] Application health endpoint did not respond."
        cat "$log_file"

        kill "$pf_pid" 2>/dev/null || true
        wait "$pf_pid" 2>/dev/null || true

        return 1
    fi

    # Get final HTTP status
    http_code="$(curl -sS \
        -o /dev/null \
        -w '%{http_code}' \
        --max-time 10 \
        "$url")" || http_code="000"

    # Stop port-forward
    kill "$pf_pid" 2>/dev/null || true
    wait "$pf_pid" 2>/dev/null || true

    echo "[INFO] Health endpoint: $url"
    echo "[INFO] HTTP status: $http_code"

    [[ "$http_code" =~ ^2[0-9][0-9]$ ]]
}

# --------------------------------------------------
# Execute all health checks
# --------------------------------------------------

check "Deployment readiness" check_deployment

check "Pod readiness" check_pods

check "Kubernetes Service" check_service

check "Deployment rollout" check_rollout

check "Application HTTP endpoint" check_http

# --------------------------------------------------
# Health check summary
# --------------------------------------------------

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

exit 0
