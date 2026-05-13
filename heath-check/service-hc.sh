#!/bin/bash
# ==============================================================================
# service-hc.sh — External Service & Harbor Registry Health Check
# Target: Supervisor 외부 노출 서비스(LoadBalancer) + Harbor Registry
# Usage: bash service-hc.sh
# Prerequisite: kubectl context must be set to the target Supervisor
# ==============================================================================

# --- Colors & Emojis ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

CHECK_TIME=$(date "+%Y-%m-%d %H:%M:%S")    # Fix: $() 방식으로 변경

echo -e "${BLUE}================================================================================${NC}"
echo -e "  🌐 ${BLUE}EXTERNAL SERVICE HEALTH CHECK (/readyz)${NC} | ${CHECK_TIME}"
echo -e "${BLUE}================================================================================${NC}"
printf "%-25s %-30s %-18s %s\n" "NAMESPACE" "SERVICE" "EXTERNAL-IP" "STATUS"
echo -e "-------------------------  ----------------------------  ----------------  ------"

# Supervisor API 서버 (port 6443)의 External LoadBalancer 서비스 조회
# Fix: awk 조건에서 누락된 $5 변수 추가
kubectl get svc -A --no-headers \
  | awk '$1 != "kube-system" && $5 != "<none>" && $5 != "<pending>" && $6 ~ /6443/ {print $1, $2, $5}' \
  | while read -r NS SVC IP; do

    TARGET="https://$IP:6443/readyz"
    HTTP_STATUS=$(curl -sk -o /dev/null -w "%{http_code}" --connect-timeout 3 "$TARGET")

    case "$HTTP_STATUS" in
        200) RESULT="✅ ${GREEN}200 OK${NC}"           ;;
        000) RESULT="❌ ${RED}TIMEOUT/UNREACHABLE${NC}" ;;
        *)   RESULT="⚠️  ${YELLOW}HTTP ${HTTP_STATUS}${NC}" ;;
    esac

    printf "%-25s %-30s %-18s %b\n" "$NS" "$SVC" "$IP" "$RESULT"
done

echo -e "${BLUE}================================================================================${NC}"

# --- Harbor Registry Health Check ---
# 환경에 맞게 인스턴스 목록 수정
HARBOR_INSTANCES=(
    "https://harbor.psolab.local"
    # "https://harbor2.psolab.local"   # 추가 인스턴스는 여기에
)

echo -e "\n  🗄️  ${BLUE}HARBOR REGISTRY HEALTH CHECK${NC}"
echo -e "${BLUE}================================================================================${NC}"
printf "%-70s %s\n" "Harbor URL" "STATUS"
echo -e "----------------------------------------------------------------------  ------"

for URL in "${HARBOR_INSTANCES[@]}"; do
    PING_URL="${URL}/api/v2.0/ping"
    RESPONSE=$(curl -sk --max-time 5 "$PING_URL")

    if [[ "$RESPONSE" == *"Pong"* ]]; then
        STATUS="✅ ${GREEN}ONLINE${NC}"
    else
        STATUS="❌ ${RED}OFFLINE (Response: ${RESPONSE:0:30})${NC}"
    fi

    printf "%-70s %b\n" "$URL" "$STATUS"
done

echo -e "${BLUE}================================================================================${NC}"
