#!/usr/bin/env bash

set -Eeuo pipefail

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
echo " Jenkins CI Environment Check"
echo "======================================"

# Required CI tools
for tool in java docker python3 git; do
    if command -v "$tool" >/dev/null 2>&1; then
        pass "$tool is installed"
    else
        fail "$tool is missing"
    fi
done

echo
echo "---------- Java ----------"

if command -v java >/dev/null 2>&1; then
    java -version 2>&1 | head -n 1
fi

echo
echo "---------- Python Dependencies ----------"

if python3 -c "import yaml, jsonschema" >/dev/null 2>&1; then
    pass "PyYAML and jsonschema are installed"
else
    fail "PyYAML or jsonschema is missing"
fi

echo
echo "---------- Docker ----------"

if docker info >/dev/null 2>&1; then
    pass "Docker daemon is reachable"
else
    fail "Docker daemon is not reachable"
fi

echo
echo "======================================"
echo " CI Environment Summary"
echo "======================================"
echo "PASS: $PASS"
echo "FAIL: $FAIL"

if (( FAIL > 0 )); then
    echo "[FAIL] Jenkins CI environment is not ready."
    exit 1
fi

echo "[PASS] Jenkins CI environment is ready."
