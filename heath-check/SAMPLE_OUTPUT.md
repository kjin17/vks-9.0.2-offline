# Health Check Scripts — 예상 출력 샘플

> 실제 환경 데이터 기반의 예상 출력 예시입니다.  
> 모든 스크립트는 `bash <script>.sh` 로 실행합니다.

---

## 1. avi-hc.sh — NSX ALB Health Check

```
--- NSX ALB Targeted Health Report (UUID Mode) ---
Enter Controller IP/FQDN: 10.10.10.20
Username: admin
Password: ********

✅ Authentication successful.

Tenant          | Virtual Service                     | Status
----------------------------------------------------------------------
admin           | vs-supervisor-api                   | ✅ UP
admin           | vs-harbor-frontend                  | ✅ UP
psolab-tenant   | vs-app-prod-01                      | ✅ UP
psolab-tenant   | vs-app-staging-01                   | ❌ DOWN
psolab-tenant   | vs-maintenance-test                 | ⚪ DISABLED


### Infrastructure Summary ###
Tenant Name          | Total VS             | Total SE
-----------------------------------------------------------------
admin                | 🌐 2                 | ⚙️  2
psolab-tenant        | 🌐 3                 | ⚙️  4
```

> ⚠️ `vs-app-staging-01` 이 DOWN 상태 — Pool 멤버 상태 또는 백엔드 서버 확인 필요

---

## 2. service-hc.sh — External Service & Harbor Health Check

```
================================================================================
  🌐 EXTERNAL SERVICE HEALTH CHECK (/readyz) | 2026-05-13 23:00:00
================================================================================
NAMESPACE                 SERVICE                        EXTERNAL-IP        STATUS
-------------------------  ----------------------------  ----------------  ------
vmware-system-supervisor  kube-apiserver-lb-svc          10.10.10.100       ✅ 200 OK
vmware-system-supervisor  kube-apiserver-lb-svc-2        10.10.10.101       ✅ 200 OK
vmware-system-supervisor  kube-apiserver-lb-svc-3        10.10.10.102       ✅ 200 OK
================================================================================

  🗄️  HARBOR REGISTRY HEALTH CHECK
================================================================================
Harbor URL                                                             STATUS
----------------------------------------------------------------------  ------
https://harbor.psolab.local                                            ✅ ONLINE
================================================================================
```

> Supervisor VIP 3개 모두 `/readyz 200 OK` → Control Plane HA 정상

---

## 3. sup-hc.sh — Supervisor Cluster Health Check

```
==========================================================
  🛡️  SUPERVISOR CLUSTER HEALTH MONITOR | 2026-05-13 23:00:00
==========================================================

🧠 CONTROL PLANE & DATABASE:
  Checking API Server Connectivity... ✅ ONLINE
  ✅ API Latency: 87ms (Excellent)

📡 NODE STATUS:
  ✅ ALL NODES READY (3/3)

⚙️  SYSTEM SERVICES HEALTH:
  ✅ ALL SYSTEM PODS RUNNING

📊 STORAGE CAPACITY (Persistent Volumes):
  💾 Total Provisioned PVs: 24
  📏 Total Storage Claimed: 2480.00 GiB

  ---------------------------------------------------------------
  StorageClass                   | PV Count   | Total Claimed
  -------------------------------------------------------------
  vsan-default-storage-policy    | 18         | 1920.00 GiB
  pacific-gold-storage-policy    | 6          | 560.00 GiB
  ---------------------------------------------------------------

💾 COMPLIANCE & HEALTH:
  ✅ All PVCs are Bound and Healthy

📂 TOP NAMESPACE USAGE (by PVC count):
  - Namespace [prod-namespace                   ] 8 volumes
  - Namespace [dev-namespace                    ] 5 volumes
  - Namespace [vmware-system-vks-public         ] 4 volumes

🌐 NETWORKING & LOAD BALANCER:
  ✅ Load Balancer: All 12 VIPs Allocated

📊 RESOURCE QUOTAS:
  ✅ Quotas: All Namespaces within limits

🏗️  VKS CLUSTER STATUS:
  prod-namespace/cluster-prod-01              ✅ Running
  prod-namespace/cluster-prod-02              ✅ Running
  dev-namespace/cluster-dev-01                ✅ Running
  dev-namespace/cluster-dev-02                ⏳ Provisioning

========================= END REPORT =========================
```

> ⚠️ `cluster-dev-02` 가 Provisioning 상태 — 정상 진행 중이거나 장시간 지속 시 vCenter Task 확인

---

## 4. vcfa-hc.sh — VCFA System Health Check

```
================================================================================
  🌐 VCFA System Health Report | 2026-05-13 23:00:00
  📍 Endpoint: https://vcfa.psolab.local/status
================================================================================
Gathering VCFA System Health Report...

  Total Services: 18  |  ✅ OK: 16  |  ❌ FAIL: 2

SERVICE NAME                                       HEALTH       COMPONENT          GROUP           CLUSTER
-----------------------------------------------------------------------------------------------------------------------
argocd-application-controller                      ✅ OK        argocd             core            vcfa-cluster-01
argocd-server                                      ✅ OK        argocd             core            vcfa-cluster-01
cert-manager                                       ✅ OK        platform           infra           vcfa-cluster-01
contour-envoy                                      ✅ OK        network            infra           vcfa-cluster-01
harbor-core                                        ✅ OK        registry           storage         vcfa-cluster-01
harbor-database                                    ✅ OK        registry           storage         vcfa-cluster-01
harbor-jobservice                                  ❌ FAIL      registry           storage         vcfa-cluster-01
harbor-redis                                       ✅ OK        registry           storage         vcfa-cluster-01
istio-ingressgateway                               ✅ OK        network            infra           vcfa-cluster-01
prelude-orchestrator                               ✅ OK        platform           core            vcfa-cluster-01
synthetic-checker                                  ❌ FAIL      monitoring         platform        vcfa-cluster-01
vksm-controller                                    ✅ OK        vksm               platform        vcfa-cluster-01
vmsp-api                                           ✅ OK        platform           api             vcfa-cluster-01
vmsp-fleet-depot                                   ✅ OK        platform           distribution    vcfa-cluster-01
vmsp-identity                                      ✅ OK        platform           auth            vcfa-cluster-01
vmsp-platform                                      ✅ OK        platform           core            vcfa-cluster-01
vmsp-telemetry                                     ✅ OK        monitoring         telemetry       vcfa-cluster-01
vmsp-ui                                            ✅ OK        platform           ui              vcfa-cluster-01
-----------------------------------------------------------------------------------------------------------------------

⚠️  FAILED SERVICES:
  ❌ harbor-jobservice (component: registry)
  ❌ synthetic-checker (component: monitoring)

================================================================================
```

> 조치 예시:
> - `harbor-jobservice` FAIL → `kubectl rollout restart deployment harbor-jobservice -n harbor` 시도
> - `synthetic-checker` FAIL → 모니터링 에이전트 상태 확인, 일시적 오류일 경우 재시작 가능

---

## 스크립트 실행 방법

```bash
# 실행 권한 부여 (최초 1회)
chmod +x ~/study/vks-9.0.2-offline/heath-check/*.sh

# 각 스크립트 실행
bash avi-hc.sh                           # NSX ALB 상태 (대화형: IP/계정 입력)
bash service-hc.sh                       # 외부 서비스 + Harbor 상태
bash sup-hc.sh                           # Supervisor 클러스터 상태
VCFA_HOST=vcfa.psolab.local bash vcfa-hc.sh   # VCFA 서비스 상태

# 전체 일괄 실행 (하루 1회 점검 시)
for script in avi-hc service-hc sup-hc; do
    echo "===== Running ${script}.sh ====="
    bash ~/study/vks-9.0.2-offline/heath-check/${script}.sh
done
VCFA_HOST=vcfa.psolab.local bash ~/study/vks-9.0.2-offline/heath-check/vcfa-hc.sh
```
