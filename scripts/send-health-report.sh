
#!/usr/bin/env bash

set -euo pipefail

# ==================================================
# PROJECT CONFIGURATION
# ==================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

HEALTH_SCRIPT="$PROJECT_ROOT/scripts/health-check.sh"

HEALTH_CONFIG="${HEALTH_CONFIG:-$PROJECT_ROOT/project-configs/medical-appointment.yaml}"

# ==================================================
# EMAIL CONFIGURATION
# ==================================================

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

# ==================================================
# SMTP CREDENTIAL VALIDATION
# ==================================================

if [[ -z "${SMTP_USERNAME:-}" || -z "${SMTP_PASSWORD:-}" ]]; then
    echo "[ERROR] SMTP credentials are not available."
    exit 2
fi

# ==================================================
# TEMPORARY FILES
# ==================================================

umask 077

REPORT="$(mktemp)"
EMAIL="$(mktemp)"
MSMTP_CONFIG="$(mktemp)"

cleanup() {
    rm -f "$REPORT" "$EMAIL" "$MSMTP_CONFIG"
}

trap cleanup EXIT

chmod 600 "$MSMTP_CONFIG"

# ==================================================
# GMAIL SMTP CONFIGURATION
# ==================================================

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

# ==================================================
# EXECUTE HEALTH CHECK ONLY ONCE
# ==================================================

echo "[INFO] Running application health checks..."

if bash "$HEALTH_SCRIPT" "$HEALTH_CONFIG" > "$REPORT" 2>&1; then

    HEALTH_STATUS=0
    HEALTH_RESULT="SUCCESS"

    echo "[PASS] Application health checks completed."

else

    HEALTH_STATUS=$?
    HEALTH_RESULT="FAILED"

    echo "[FAIL] Application health checks detected problems."

fi

# ==================================================
# EMAIL SUBJECT
# ==================================================

if [[ "$HEALTH_STATUS" -eq 0 ]]; then
    SUBJECT="[SUCCESS] $PROJECT_NAME - Deployment Health Report"
else
    SUBJECT="[FAILED] $PROJECT_NAME - Deployment Health Report"
fi

# ==================================================
# GENERATE EMAIL BODY
# ==================================================

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

Project Name        : $PROJECT_NAME
Jenkins Job         : $JOB_NAME
Build Number        : $BUILD_NUMBER
Deployment Status   : $DEPLOYMENT_STATUS
Health Check        : $HEALTH_RESULT
Kubernetes Namespace: $NAMESPACE
Deployment Name     : $DEPLOYMENT_NAME
Build URL           : $BUILD_URL
Execution Date      : $(date '+%d-%m-%Y %H:%M:%S')

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

# ==================================================
# SEND EMAIL
# ==================================================

echo "[INFO] Sending health report to:"
echo "[INFO] To: $RECIPIENT"
echo "[INFO] CC: $CC_RECIPIENT"

if msmtp --file="$MSMTP_CONFIG" -t < "$EMAIL"; then

    echo "[PASS] Email sent successfully."

else

    echo "[ERROR] Email delivery failed."
    exit 2

fi

# ==================================================
# FINAL STATUS
# ==================================================

if [[ "$HEALTH_STATUS" -ne 0 ]]; then
    echo "[WARNING] Health checks failed. Email report was sent."
    exit "$HEALTH_STATUS"
fi

echo "[SUCCESS] Health check report generated and emailed."

exit 0
