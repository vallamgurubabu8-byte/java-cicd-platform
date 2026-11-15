#!/usr/bin/env bash

set -Eeuo pipefail

CONFIG_FILE="${1:-project-configs/medical-appointment.yaml}"

PASS=0
FAIL=0

pass() {
    echo "[PASS] $1"
    PASS=$((PASS + 1))
}

fail() {
    echo "[FAIL] $1" >&2
    FAIL=$((FAIL + 1))
}

echo "======================================"
echo " Jenkins CD Environment Check"
echo "======================================"

for tool in kubectl curl python3; do
    if command -v "$tool" >/dev/null 2>&1; then
        pass "$tool is installed"
    else
        fail "$tool is missing"
    fi
done

echo
echo "---------- Python Dependencies ----------"

if python3 -c "import yaml, jsonschema" >/dev/null 2>&1; then
    pass "PyYAML and jsonschema are installed"
else
    fail "PyYAML or jsonschema is missing"
fi

echo
echo "---------- Kubernetes Configuration ----------"

if [[ -f "$CONFIG_FILE" ]]; then
    NAMESPACE="$(python3 -c \
        'import sys,yaml; print(yaml.safe_load(open(sys.argv[1]))["deployment"]["namespace"])' \
        "$CONFIG_FILE")"
    pass "Project configuration found"
else
    fail "Configuration file not found: $CONFIG_FILE"
    NAMESPACE=""
fi

if command -v kubectl >/dev/null 2>&1; then
    if kubectl config current-context; then
        pass "Kubernetes context is available"
    else
        fail "Kubernetes context is unavailable"
    fi

    if [[ -n "$NAMESPACE" ]] &&
       kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
        pass "Kubernetes namespace $NAMESPACE is accessible"
    else
        fail "Kubernetes namespace is inaccessible"
    fi
fi

echo
echo "======================================"
echo " CD Environment Summary"
echo "======================================"
echo "PASS: $PASS"
echo "FAIL: $FAIL"

if (( FAIL > 0 )); then
    echo "[FAIL] Jenkins CD environment is not ready."
    exit 1
fi

echo "[PASS] Jenkins CD environment is ready."
