#!/usr/bin/env bash

set -u

PASS=0
WARN=0
FAIL=0

pass() {
    echo "[PASS] $1"
    ((PASS+=1))
}

warn() {
    echo "[WARN] $1"
    ((WARN+=1))
}

fail() {
    echo "[FAIL] $1"
    ((FAIL+=1))
}

echo "======================================"
echo " Java CI/CD Platform Environment Check"
echo "======================================"

# Check required tools
check_tool() {
    local tool="$1"

    if command -v "$tool" >/dev/null 2>&1; then
        pass "$tool is installed"
    else
        fail "$tool is not installed"
    fi
}

for tool in java mvn docker kubectl helm python3 curl git; do
    check_tool "$tool"
done

echo
echo "---------- Tool Versions ----------"

if command -v java >/dev/null 2>&1; then
    java -version 2>&1 | head -n 1
fi

if command -v mvn >/dev/null 2>&1; then
    mvn -version 2>&1 | head -n 1
fi

if command -v docker >/dev/null 2>&1; then
    docker --version
fi

if command -v kubectl >/dev/null 2>&1; then
    kubectl version --client
fi

if command -v helm >/dev/null 2>&1; then
    helm version --short
fi

echo
echo "---------- Python Dependencies ----------"

if command -v python3 >/dev/null 2>&1; then
    if python3 -c "import yaml, jsonschema" >/dev/null 2>&1; then
        pass "PyYAML and jsonschema are installed"
    else
        fail "PyYAML or jsonschema is missing"
    fi
fi

echo
echo "---------- Docker Status ----------"

if command -v docker >/dev/null 2>&1; then
    if docker info >/dev/null 2>&1; then
        pass "Docker daemon is running"
    else
        warn "Docker daemon is not reachable"
    fi
fi

echo
echo "---------- Kubernetes Status ----------"

if command -v kubectl >/dev/null 2>&1; then
    if kubectl get nodes --request-timeout=5s >/dev/null 2>&1; then
        pass "Kubernetes cluster is reachable"
        kubectl get nodes
    else
        warn "Kubernetes cluster is not reachable"
    fi
fi

echo
echo "---------- Local Services ----------"

check_http() {
    local name="$1"
    local url="$2"
    local expected="$3"
    local code

    code=$(curl -sS -o /dev/null -w "%{http_code}" \
        --max-time 5 "$url" 2>/dev/null || true)

    if [[ "$code" =~ $expected ]]; then
        pass "$name is reachable (HTTP $code)"
    else
        warn "$name is unavailable or returned HTTP $code"
    fi
}

if command -v curl >/dev/null 2>&1; then
    check_http "Jenkins" "http://localhost:8081/login" '^[1-5][0-9][0-9]$'
    check_http "Docker Registry" "http://localhost:5000/v2/" '^(200|401)$'
    check_http "Medical Appointment API through NGINX" \
        "http://localhost/appointments/getbystatus" '^200$'
fi

echo
echo "======================================"
echo " Environment Check Summary"
echo "======================================"
echo "PASS: $PASS"
echo "WARN: $WARN"
echo "FAIL: $FAIL"

if (( FAIL > 0 )); then
    echo "Result: Some required tools or dependencies are missing."
    exit 1
else
    echo "Result: Required tools are installed."
    exit 0
fi
