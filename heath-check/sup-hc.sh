#!/bin/bash
# ==============================================================================
# sup-hc.sh — vSphere Supervisor Cluster Daily Health Check
# Target: VCF Supervisor (TKG/VKS 환경)
# Usage: bash sup-hc.sh
# Prerequisite: kubectl context must be set to the Supervisor cluster
# ==============================================================================

# --- Colors & Emojis ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

CHECK_TIME=$(date "+%Y-%m-%d %H:%M:%S")

echo -e "${PURPLE}==========================================================${NC}"
echo -e "  🛡️  ${PURPLE}SUPERVISOR CLUSTER HEALTH MONITOR${NC} | ${CHECK_TIME}"
echo -e "${PURPLE}==========================================================${NC}"

# --- 1. API Server Connectivity ---
echo -e "\n🧠 ${PURPLE}CONTROL PLANE & DATABASE:${NC}"
echo -n "  Checking API Server Connectivity... "
if kubectl cluster-info > /dev/null 2>&1; then
    echo -e "✅ ${GREEN}ONLINE${NC}"
else
    echo -e "❌ ${RED}OFFLINE / AUTH ERROR${NC}"
    exit 1
fi

# --- 2. API Latency ---
START_TIME=$(date +%s%N)
kubectl get nodes > /dev/null 2>&1
END_TIME=$(date +%s%N)
LATENCY=$(( (END_TIME - START_TIME) / 1000000 ))

if   [ "$LATENCY" -lt 200 ]; then
    echo -e "  ✅ API Latency: ${GREEN}${LATENCY}ms (Excellent)${NC}"
elif [ "$LATENCY" -lt 500 ]; then
    echo -e "  ⚠️  API Latency: ${YELLOW}${LATENCY}ms (Degraded)${NC}"
else
    echo -e "  ❌ API Latency: ${RED}${LATENCY}ms (CRITICAL)${NC}"
fi

# --- 3. Control Plane Node Status ---
echo -e "\n📡 ${BLUE}NODE STATUS:${NC}"
NODES_READY=$(kubectl get nodes --no-headers | grep -c " Ready")
NODES_TOTAL=$(kubectl get nodes --no-headers | wc -l | tr -d ' ')

if [ "$NODES_READY" -eq "$NODES_TOTAL" ]; then
    echo -e "  ✅ ALL NODES READY (${NODES_READY}/${NODES_TOTAL})"
else
    echo -e "  ⚠️  ${YELLOW}WARNING: ONLY ${NODES_READY}/${NODES_TOTAL} NODES READY${NC}"
    kubectl get nodes --no-headers | grep -v " Ready"
fi

# --- 4. System Pod Health ---
echo -e "\n⚙️  ${BLUE}SYSTEM SERVICES HEALTH:${NC}"
BAD_PODS=$(kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers 2>/dev/null | grep -v "^$")

if [ -z "$BAD_PODS" ]; then
    echo -e "  ✅ ALL SYSTEM PODS RUNNING"
else
    echo -e "  ❌ ${RED}CRITICAL: UNHEALTHY PODS DETECTED:${NC}"
    echo "$BAD_PODS" | awk '{print "     - " $1 "/" $2 " → " $4}'
fi

# --- 5. PV Capacity (Total) ---
echo -e "\n📊 ${PURPLE}STORAGE CAPACITY (Persistent Volumes):${NC}"
RAW_CAPACITIES=$(kubectl get pv -o jsonpath='{.items[*].spec.capacity.storage}' 2>/dev/null)   # Fix: capaciti → capacity

TOTAL_GIB=0
for CAP in $RAW_CAPACITIES; do
    VALUE=$(echo "$CAP" | sed 's/[A-Za-z]//g')
    if   [[ "$CAP" == *Ti* ]]; then
        TOTAL_GIB=$(echo "$TOTAL_GIB + ($VALUE * 1024)" | bc)
    elif [[ "$CAP" == *Gi* ]]; then
        TOTAL_GIB=$(echo "$TOTAL_GIB + $VALUE" | bc)
    elif [[ "$CAP" == *Mi* ]]; then
        CONVERTED=$(echo "scale=4; $VALUE / 1024" | bc)
        TOTAL_GIB=$(echo "$TOTAL_GIB + $CONVERTED" | bc)
    fi
done

PV_COUNT=$(echo "$RAW_CAPACITIES" | wc -w | tr -d ' ')
FINAL_TOTAL=$(echo "scale=2; $TOTAL_GIB / 1" | bc)

echo -e "  💾 Total Provisioned PVs: ${PURPLE}${PV_COUNT}${NC}"
echo -e "  📏 Total Storage Claimed: ${GREEN}${FINAL_TOTAL} GiB${NC}"

# --- 6. PV Usage per StorageClass ---
STORAGE_CLASSES=$(kubectl get pv -o jsonpath='{.items[*].spec.storageClassName}' 2>/dev/null | tr ' ' '\n' | sort -u)

echo -e "\n---------------------------------------------------------------"
printf "  %-30s | %-10s | %-15s\n" "StorageClass" "PV Count" "Total Claimed"
echo -e "  -------------------------------------------------------------"

for SC in $STORAGE_CLASSES; do
    SC_CAPS=$(kubectl get pv -o jsonpath="{.items[?(@.spec.storageClassName=='${SC}')].spec.capacity.storage}" 2>/dev/null)   # Fix: capaciti → capacity
    SC_TOTAL=0

    for CAP in $SC_CAPS; do
        VALUE=$(echo "$CAP" | sed 's/[A-Za-z]//g')
        if   [[ "$CAP" == *Ti* ]]; then
            SC_TOTAL=$(echo "$SC_TOTAL + ($VALUE * 1024)" | bc)
        elif [[ "$CAP" == *Gi* ]]; then
            SC_TOTAL=$(echo "$SC_TOTAL + $VALUE" | bc)
        elif [[ "$CAP" == *Mi* ]]; then
            CONVERTED=$(echo "scale=4; $VALUE / 1024" | bc)
            SC_TOTAL=$(echo "$SC_TOTAL + $CONVERTED" | bc)
        fi
    done  # Fix: 마지막 if → fi 오타 수정

    SC_PV_COUNT=$(echo "$SC_CAPS" | wc -w | tr -d ' ')
    SC_FINAL=$(echo "scale=2; $SC_TOTAL / 1" | bc)
    printf "  %-30s | %-10s | %-15s\n" "$SC" "$SC_PV_COUNT" "${SC_FINAL} GiB"
done

echo -e "  -------------------------------------------------------------"

# --- 7. PVC Compliance ---
echo -e "\n💾 ${PURPLE}COMPLIANCE & HEALTH:${NC}"
UNBOUND_PVC=$(kubectl get pvc -A --no-headers 2>/dev/null | grep -v "Bound" | wc -l | tr -d ' ')

if [ "$UNBOUND_PVC" -eq 0 ]; then
    echo -e "  ✅ All PVCs are ${GREEN}Bound and Healthy${NC}"
else
    echo -e "  ❌ ${RED}CRITICAL: ${UNBOUND_PVC} Unbound PVC(s) detected!${NC}"
    kubectl get pvc -A --no-headers | grep -v "Bound"
fi

# --- 8. Top Namespace by Volume Count ---
echo -e "\n📂 ${PURPLE}TOP NAMESPACE USAGE (by PVC count):${NC}"
kubectl get pvc -A --no-headers 2>/dev/null \
    | awk '{print $1}' | sort | uniq -c | sort -nr | head -5 \
    | awk '{printf "  - Namespace [%-30s] %s volumes\n", $2, $1}'

# --- 9. Load Balancer Status ---
echo -e "\n🌐 ${PURPLE}NETWORKING & LOAD BALANCER:${NC}"
PENDING_LB=$(kubectl get svc -A --no-headers 2>/dev/null | grep "LoadBalancer" | grep -c "<pending>" || true)
TOTAL_LB=$(kubectl get svc -A --no-headers 2>/dev/null | grep -c "LoadBalancer" || true)

if [ "$PENDING_LB" -eq 0 ]; then
    echo -e "  ✅ Load Balancer: ${GREEN}All ${TOTAL_LB} VIPs Allocated${NC}"
else
    echo -e "  ❌ Load Balancer: ${RED}${PENDING_LB} VIPs Pending (Check Avi IP Pool!)${NC}"
fi

# --- 10. Resource Quota Check ---
echo -e "\n📊 ${PURPLE}RESOURCE QUOTAS:${NC}"
QUOTA_FULL=$(kubectl get resourcequota -A -o json 2>/dev/null \
    | jq '[.items[] | select(.status.used.cpu == .status.hard.cpu)] | length')

if [ "$QUOTA_FULL" -eq 0 ]; then
    echo -e "  ✅ Quotas: ${GREEN}All Namespaces within limits${NC}"
else
    echo -e "  ⚠️  Quotas: ${YELLOW}${QUOTA_FULL} Namespace(s) at 100% CPU capacity${NC}"
fi

# --- 11. VKS Cluster Status ---
echo -e "\n🏗️  ${PURPLE}VKS CLUSTER STATUS:${NC}"
kubectl get tkc -A --no-headers 2>/dev/null \
    | awk '{printf "  %-40s %s\n", $1"/"$2, $4}' \
    | sed 's/True/✅ Running/g' \
    | sed 's/Provisioning/⏳ Provisioning/g' \
    | sed 's/False/❌ Error/g' \
    | sed 's/Deleting/🗑️  Deleting/g'

echo -e "\n${BLUE}========================= END REPORT =========================${NC}\n"
