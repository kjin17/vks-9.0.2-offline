#!/bin/bash
# ==============================================================================
# vcfa-hc.sh — VCF Automation (VCFA) System Health Check
# Target: VCFA /status endpoint (JSON 기반 서비스 상태 조회)
# Usage: VCFA_HOST=vcfa.psolab.local bash vcfa-hc.sh
#        또는 스크립트 내 VCFA_HOST 직접 수정
# ==============================================================================

# --- Configuration ---
# 환경에 맞게 수정 (또는 환경변수로 주입: export VCFA_HOST=vcfa.psolab.local)
VCFA_HOST="${VCFA_HOST:-vcfa.psolab.local}"                     # Fix: placeholder URL 제거
URL="https://${VCFA_HOST}/status"                               # Fix: http:test.local → https:// 형식

# --- Colors ---
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[1;34m'
BOLD='\033[1m'
NC='\033[0m'

CHECK_TIME=$(date "+%Y-%m-%d %H:%M:%S")                         # Fix: =(...) → $(...) 방식

echo -e "${BLUE}================================================================================${NC}"
echo -e "  🌐 ${BLUE}VCFA System Health Report${NC} | ${CHECK_TIME}"
echo -e "  📍 Endpoint: ${URL}"
echo -e "${BLUE}================================================================================${NC}"
echo -e "${BLUE}Gathering VCFA System Health Report...${NC}\n"

# Fetch JSON data (--insecure: 사설 인증서 환경)
RESPONSE=$(curl -sk --max-time 10 "$URL")

if [ $? -ne 0 ] || [ -z "$RESPONSE" ]; then
    echo -e "${RED}❌ FAILURE: Could not reach status endpoint.${NC}"
    echo -e "  → URL: ${URL}"
    echo -e "  → Tip: VCFA_HOST 환경변수 또는 스크립트 내 VCFA_HOST 값 확인"
    exit 1
fi

# Validate JSON
if ! echo "$RESPONSE" | jq . > /dev/null 2>&1; then
    echo -e "${RED}❌ FAILURE: Invalid JSON response.${NC}"
    echo "Raw response: ${RESPONSE:0:200}"
    exit 1
fi

# --- Summary Counts ---
TOTAL=$(echo "$RESPONSE" | jq '[to_entries[]] | length')
OK_COUNT=$(echo "$RESPONSE" | jq '[to_entries[] | select(.value.ok == true)] | length')
FAIL_COUNT=$(echo "$RESPONSE" | jq '[to_entries[] | select(.value.ok == false)] | length')

echo -e "  Total Services: ${BOLD}${TOTAL}${NC}  |  ✅ OK: ${GREEN}${OK_COUNT}${NC}  |  ❌ FAIL: ${RED}${FAIL_COUNT}${NC}\n"

# --- Table ---
printf "${BOLD}%-50s %-12s %-18s %-15s %-30s${NC}\n" \
    "SERVICE NAME" "HEALTH" "COMPONENT" "GROUP" "CLUSTER"
echo "-----------------------------------------------------------------------------------------------------------------------"

echo "$RESPONSE" | jq -r \
    'to_entries[] | "\(.key)|\(.value.ok)|\(.value.labels.component // "N/A")|\(.value.labels.group // "N/A")|\(.value.labels.clustername // "N/A")"' \
    | while IFS='|' read -r name ok component group cluster; do

    if [ "$ok" == "true" ]; then
        STATUS_OUT="${GREEN}✅ OK${NC}"
    else
        STATUS_OUT="${RED}❌ FAIL${NC}"
    fi

    printf "%-50s %-10b %-18s %-15s %-30s\n" "$name" "$STATUS_OUT" "$component" "$group" "$cluster"
done

echo -e "-----------------------------------------------------------------------------------------------------------------------"

# --- Failed Services (별도 강조) ---
if [ "$FAIL_COUNT" -gt 0 ]; then
    echo -e "\n${RED}⚠️  FAILED SERVICES:${NC}"
    echo "$RESPONSE" | jq -r \
        'to_entries[] | select(.value.ok == false) | "  ❌ \(.key) (component: \(.value.labels.component // "N/A"))"'
fi

echo -e "\n${BLUE}================================================================================${NC}\n"
