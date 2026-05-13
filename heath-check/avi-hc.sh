#!/bin/bash
# ==============================================================================
# avi-hc.sh — NSX Advanced Load Balancer (Avi) Daily Health Check
# Target: Avi Controller (NSX ALB) 31.1.x
# Usage: bash avi-hc.sh
# ==============================================================================

# --- Configuration ---
API_VERSION="31.1.2"          # Avi REST API version (match controller version)

echo "--- NSX ALB Targeted Health Report (UUID Mode) ---"
read -p "Enter Controller IP/FQDN: " CONTROLLER_IP
CONTROLLER="https://${CONTROLLER_IP}"

# --- Credentials ---
read -p "Username: " USERNAME
read -rs -p "Password: " PASSWORD
echo -e "\n"

COOKIE_FILE=$(mktemp)
TMPDIR_SUMMARY=$(mktemp -d)

# --- 1. Authenticate ---
curl -s -k -i -X POST "${CONTROLLER}/login" \
    --data-urlencode "username=${USERNAME}" \
    --data-urlencode "password=${PASSWORD}" \
    -c "${COOKIE_FILE}" \
    -H "X-Avi-Version: ${API_VERSION}" \
    -H "Referer: ${CONTROLLER}/" > /dev/null

CSRF_TOKEN=$(grep "csrftoken" "${COOKIE_FILE}" | awk '{print $NF}')

if [[ -z "$CSRF_TOKEN" ]]; then
    echo "❌ Auth Failed. Check credentials or controller connectivity."
    rm -f "$COOKIE_FILE"
    exit 1
fi
echo "✅ Authentication successful."

# --- 2. Detailed Table Header ---
printf "\n%-15s | %-35s | %-15s\n" "Tenant" "Virtual Service" "Status"
printf "%.s-" {1..70}
echo

# Get Tenants
TENANTS=$(curl -s -k -X GET "${CONTROLLER}/api/tenant" \
    -b "${COOKIE_FILE}" -H "X-CSRFToken: ${CSRF_TOKEN}" \
    -H "X-Avi-Version: ${API_VERSION}" \
    -H "Referer: ${CONTROLLER}/" | jq -r '.results[].name')

for TENANT in $TENANTS; do
    # Step A: Get VS List (Names and UUIDs)
    VS_LIST_JSON=$(curl -s -k -X GET "${CONTROLLER}/api/virtualservice" \
        -b "${COOKIE_FILE}" -H "X-CSRFToken: ${CSRF_TOKEN}" \
        -H "X-Avi-Version: ${API_VERSION}" \
        -H "X-Avi-Tenant: ${TENANT}" \
        -H "Referer: ${CONTROLLER}/")

    VS_CNT=$(echo "$VS_LIST_JSON" | jq '.results | length' 2>/dev/null || echo 0)
    echo "${TENANT} ${VS_CNT}" >> "${TMPDIR_SUMMARY}/vs_count.txt"

    # Step B: Loop through each VS — get targeted runtime status
    while IFS='|' read -r uuid name; do
        RUNTIME_JSON=$(curl -s -k -X GET "${CONTROLLER}/api/virtualservice/${uuid}/runtime" \
            -b "${COOKIE_FILE}" -H "X-CSRFToken: ${CSRF_TOKEN}" \
            -H "X-Avi-Version: ${API_VERSION}" \
            -H "X-Avi-Tenant: ${TENANT}" \
            -H "Referer: ${CONTROLLER}/")

        STATE=$(echo "$RUNTIME_JSON" | jq -r '.oper_status.state' 2>/dev/null)

        case "$STATE" in
            OPER_UP)       EMOJI="✅ UP"       ;;
            OPER_DOWN)     EMOJI="❌ DOWN"     ;;
            OPER_DISABLED) EMOJI="⚪ DISABLED" ;;
            *)             EMOJI="⚠️  $STATE"  ;;
        esac

        printf "%-15s | %-35s | %-15s\n" "$TENANT" "$name" "$EMOJI"
    done < <(echo "$VS_LIST_JSON" | jq -r '.results[] | "\(.uuid)|\(.name)"')

    # Step C: SE Count (tmpfile 방식 — 서브쉘 문제 방지)
    SE_CNT=$(curl -s -k -X GET "${CONTROLLER}/api/serviceengine" \
        -b "${COOKIE_FILE}" -H "X-CSRFToken: ${CSRF_TOKEN}" \
        -H "X-Avi-Version: ${API_VERSION}" \
        -H "X-Avi-Tenant: ${TENANT}" \
        -H "Referer: ${CONTROLLER}/" | jq '.results | length' 2>/dev/null || echo 0)
    echo "${TENANT} ${SE_CNT}" >> "${TMPDIR_SUMMARY}/se_count.txt"
done

# --- 3. Summary Table ---
echo -e "\n\n### Infrastructure Summary ###"
printf "%-20s | %-20s | %-20s\n" "Tenant Name" "Total VS" "Total SE"
printf "%.s-" {1..65}
echo

while read -r tenant vs_count; do
    se_count=$(grep "^${tenant} " "${TMPDIR_SUMMARY}/se_count.txt" | awk '{print $2}' || echo 0)
    printf "%-20s | %-20s | %-20s\n" "$tenant" "🌐 ${vs_count}" "⚙️  ${se_count}"
done < "${TMPDIR_SUMMARY}/vs_count.txt"

# Cleanup
rm -f "$COOKIE_FILE"
rm -rf "$TMPDIR_SUMMARY"
