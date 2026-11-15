
#!/bin/bash

set -uo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HEALTH_SCRIPT="$PROJECT_DIR/scripts/health-check.sh"

SENDER="vallamgurubabu@gmail.com"
RECIPIENT="vallamgurubabu8@gmail.com"
CC_RECIPIENT="sureshtechie69@gmail.com,gurubabuvallam@gmail.com"

PROJECT_NAME="${PROJECT_NAME:-Medical Appointment API}"
JOB_NAME="${JOB_NAME:-Local Execution}"
BUILD_NUMBER="${BUILD_NUMBER:-Manual}"
BUILD_URL="${BUILD_URL:-Not available}"
NAMESPACE="${NAMESPACE:-medical-appointment}"
DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-medical-appointment-api-generic-test}"
DEPLOYMENT_STATUS="${DEPLOYMENT_STATUS:-SUCCESS}"

# Credentials are supplied by Jenkins
if [[ -z "${SMTP_USERNAME:-}" || -z "${SMTP_PASSWORD:-}" ]]; then
    echo "[ERROR] SMTP credentials are not available."
    exit 2
fi

REPORT="$(mktemp)"
EMAIL="$(mktemp)"
MSMTP_CONFIG="$(mktemp)"

cleanup() {
    rm -f "$REPORT" "$EMAIL" "$MSMTP_CONFIG"
}
trap cleanup EXIT

chmod 600 "$MSMTP_CONFIG"

# Generate temporary Gmail SSL configuration
cat > "$MSMTP_CONFIG" <<EOF
defaults
auth on
tls on
tls_starttls off
tls_trust_file /etc/ssl/certs/ca-certificates.crt

account gmail
host smtp.gmail.com
port 465
from $SMTP_USERNAME
user $SMTP_USERNAME
password $SMTP_PASSWORD

account default : gmail
EOF

echo "[INFO] Running application health checks..."

if bash "$HEALTH_SCRIPT"; then
    HEALTH_STATUS=0
    HEALTH_RESULT="SUCCESS"
else
    HEALTH_STATUS=$?
    HEALTH_RESULT="FAILED"
fi

# Capture health-check output for the report
if bash "$HEALTH_SCRIPT" > "$REPORT" 2>&1; then
    HEALTH_STATUS=0
    HEALTH_RESULT="SUCCESS"
else
    HEALTH_STATUS=$?
    HEALTH_RESULT="FAILED"
fi

if [ "$HEALTH_STATUS" -eq 0 ]; then
    SUBJECT="[SUCCESS] $PROJECT_NAME - Deployment Health Report"
else
    SUBJECT="[FAILED] $PROJECT_NAME - Deployment Health Report"
fi

{
    printf 'From: %s\n' "$SENDER"
    printf 'To: %s\n' "$RECIPIENT"
    printf 'Cc: %s\n' "$CC_RECIPIENT"
    printf 'Subject: %s\n' "$SUBJECT"
    printf 'Date: %s\n' "$(date -R)"
    printf 'MIME-Version: 1.0\n'
    printf 'Content-Type: text/plain; charset=UTF-8\n'
    printf '\n'

    cat <<EOF
Hello Team,

The Continuous Deployment pipeline has completed.

==================================================
DEPLOYMENT INFORMATION
==================================================

Project Name       : $PROJECT_NAME
Jenkins Job        : $JOB_NAME
Build Number       : $BUILD_NUMBER
Deployment Status  : $DEPLOYMENT_STATUS
Health Check       : $HEALTH_RESULT
Kubernetes Namespace: $NAMESPACE
Deployment Name    : $DEPLOYMENT_NAME
Build URL          : $BUILD_URL
Execution Date     : $(date '+%d-%m-%Y %H:%M:%S')

==================================================
HEALTH CHECK REPORT
==================================================

EOF

    cat "$REPORT"

    cat <<EOF

Regards,
Java CI/CD Automation
Jenkins Notification Service

This is an automated email.
EOF
} > "$EMAIL"

echo "[INFO] Sending health report..."

if msmtp --file="$MSMTP_CONFIG" -t < "$EMAIL"; then
    echo "[PASS] Email sent successfully."
else
    echo "[ERROR] Email delivery failed."
    exit 2
fi

exit "$HEALTH_STATUS"
