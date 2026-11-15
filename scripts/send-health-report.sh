#!/bin/bash

# Java CI/CD Platform - Deployment Health Report

set -uo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HEALTH_SCRIPT="$PROJECT_DIR/scripts/health-check.sh"

# Email recipients
SENDER="vallamgurubabu@gmail.com"
RECIPIENT="vallamgurubabu8@gmail.com"
CC_RECIPIENT="sureshtechie69@gmail.com,gurubabuvallam@gmail.com"

# Jenkins build details
PROJECT_NAME="${PROJECT_NAME:-Medical Appointment API}"
JOB_NAME="${JOB_NAME:-Local Execution}"
BUILD_NUMBER="${BUILD_NUMBER:-Manual}"
BUILD_URL="${BUILD_URL:-Not available}"
NAMESPACE="${NAMESPACE:-medical-appointment}"
DEPLOYMENT_NAME="${DEPLOYMENT_NAME:-medical-appointment-api-generic-test}"
DEPLOYMENT_STATUS="${DEPLOYMENT_STATUS:-SUCCESS}"

REPORT="$(mktemp)"
EMAIL="$(mktemp)"

trap 'rm -f "$REPORT" "$EMAIL"' EXIT

echo "Starting application health checks..."

if [ ! -f "$HEALTH_SCRIPT" ]; then
    echo "[ERROR] Health check script not found: $HEALTH_SCRIPT" > "$REPORT"
    HEALTH_STATUS=1
else
    bash "$HEALTH_SCRIPT" > "$REPORT" 2>&1
    HEALTH_STATUS=$?
fi

if [ "$HEALTH_STATUS" -eq 0 ]; then
    SUBJECT="[SUCCESS] $PROJECT_NAME - Deployment Health Report"
    HEALTH_RESULT="SUCCESS"
else
    SUBJECT="[FAILED] $PROJECT_NAME - Deployment Health Report"
    HEALTH_RESULT="FAILED"
fi

# Construct email headers and body
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

The Continuous Deployment pipeline has completed its deployment stage.
Please find the application health-check report below.

==================================================
             DEPLOYMENT INFORMATION
==================================================

Project Name       : $PROJECT_NAME
Jenkins Job        : $JOB_NAME
Build Number       : $BUILD_NUMBER
Deployment Status  : $DEPLOYMENT_STATUS
Health Check       : $HEALTH_RESULT
Kubernetes Namespace : $NAMESPACE
Deployment Name    : $DEPLOYMENT_NAME
Build URL          : $BUILD_URL
Execution Date     : $(date '+%d-%m-%Y %H:%M:%S')

==================================================
                HEALTH CHECK REPORT
==================================================

EOF

    cat "$REPORT"

    cat <<EOF

==================================================
                    SUMMARY
==================================================

Project: $PROJECT_NAME
Deployment: $DEPLOYMENT_STATUS
Health Check: $HEALTH_RESULT

Regards,
Java CI/CD Automation
Jenkins Notification Service

This is an automated email. Please do not reply.
EOF
} > "$EMAIL"

# Send email to To and CC recipients
if msmtp --account=gmail -t < "$EMAIL"; then
    echo "[PASS] Health report email sent successfully."
    echo "[INFO] To: $RECIPIENT"
    echo "[INFO] CC: $CC_RECIPIENT"
else
    echo "[ERROR] Failed to send health report email."
    exit 2
fi

# Return health-check result
exit "$HEALTH_STATUS"
