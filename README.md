# VMware VCF VKS 9.0.2 — Offline (Air-Gapped) 배포 리포지토리

> **대상 버전:** VCF 9.0.2 / VKS 3.5.0  
> **환경:** 인터넷 차단(Air-Gapped), Private Harbor Registry 사용

---

## 📁 디렉토리 구조

```
vks-9.0.2-offline/
│
├── README.md                          # 이 파일
│
├── offline-prep.md                    # Offline 설치 사전 준비 (다운로드 목록 및 절차)
├── offline-install.md                 # Offline 설치 순서 및 절차 (STEP 1~14)
│
├── enable-wcp.sh                      # Supervisor Multi-Zone 배포 스크립트
├── enable_on_zone_vpc.json            # Supervisor Multi-Zone VPC 환경 구성 파일
│
├── download-extensions.sh             # VKSm Extension 이미지 다운로드 스크립트
├── upload-extensions.sh               # VKSm Extension 이미지 업로드 스크립트
│
├── Supervisor/                        # Supervisor Service 패키지 파일
│   ├── Harbor/
│   │   ├── legacy-harbor-svs-v2.14.2+vmware.2-vks.1-25220498.yml   # Harbor Service 패키지
│   │   └── Harborharbor-data-values-v2.14.2.yml                     # Harbor Data Values
│   ├── Contour/
│   │   ├── contour-service-v1.32.0.yml                               # Contour Service 패키지
│   │   └── contour-data-values-v1.32.yml                             # Contour Data Values
│   ├── VKS/
│   │   ├── 3.5.0-package.yaml                                        # VKS Service 패키지 (3.5.0)
│   │   └── 3.6.0-package.yaml                                        # VKS Service 패키지 (3.6.0)
│   └── LCI/
│       └── lci-svs-9.0.2.yaml                                        # LCI Service 패키지
│
└── heath-check/                       # 일일 점검 스크립트
    ├── avi-hc.sh                      # NSX ALB (Avi) 상태 점검
    ├── service-hc.sh                  # 외부 서비스 & Harbor Registry 상태 점검
    ├── sup-hc.sh                      # Supervisor 클러스터 상태 점검
    ├── vcfa-hc.sh                     # VCFA 시스템 상태 점검
    └── SAMPLE_OUTPUT.md               # 각 점검 스크립트 예상 출력 샘플
```

---

## 📄 주요 문서

| 파일 | 설명 |
|------|------|
| [`offline-prep.md`](./offline-prep.md) | Offline 배포 전 사전 준비 — 컴포넌트별 다운로드 목록, Harbor VM 구성, VKR Content Library, VCF CLI Plugin, Supervisor Services 이미지 이전, Standard Packages, VKSm Extension 다운로드 절차 |
| [`offline-install.md`](./offline-install.md) | 실제 설치 순서 — Bastion VM → Harbor → vCenter → Supervisor → VCF Context → Supervisor Services → VKSm Extension → VKS 클러스터 배포까지 STEP 1~14 상세 절차 |

---

## 🚀 Supervisor Multi-Zone 배포

VPC 환경에서 Multi-Zonal Supervisor를 API 방식으로 배포할 때 사용합니다.

### 파일 설명

| 파일 | 설명 |
|------|------|
| `enable-wcp.sh` | Supervisor 활성화 자동화 스크립트. vCenter/NSX 접속 정보 및 Zone/네트워크 변수 설정 후 실행 |
| `enable_on_zone_vpc.json` | VPC 환경 Multi-Zone Supervisor 구성 JSON 템플릿. `enable-wcp.sh`에서 환경 변수를 치환하여 vCenter API에 전달 |

### 사용 방법

```bash
# 1. enable-wcp.sh 상단 변수 수정
vi enable-wcp.sh

# 주요 설정 항목
VCENTER_HOSTNAME=<vCenter IP/FQDN>
VCENTER_USERNAME=administrator@vsphere.local
NSX_MANAGER=<NSX Manager IP>
K8S_SUP_ZONE1='<zone-1 cluster name>'
K8S_SUP_ZONE2='<zone-2 cluster name>'
K8S_SUP_ZONE3='<zone-3 cluster name>'
DEPLOYMENT_TYPE='VPC'   # VPC | NSX | AVI | FLB

# 2. 스크립트 실행
bash enable-wcp.sh
```

### 주요 변수

| 변수 | 설명 | 예시 |
|------|------|------|
| `VCENTER_HOSTNAME` | vCenter IP 또는 FQDN | `10.11.10.130` |
| `DEPLOYMENT_TYPE` | 배포 유형 | `VPC` / `NSX` / `AVI` / `FLB` |
| `K8S_SUP_ZONE1~3` | Supervisor Zone 클러스터명 | `zone-cl01` |
| `SUPERVISOR_SIZE` | Supervisor VM 크기 | `TINY` / `SMALL` / `MEDIUM` / `LARGE` |
| `SUPERVISOR_VM_COUNT` | Supervisor VM 수 | `1` (테스트) / `3` (운영) |
| `K8S_SERVICE_SUBNET` | Kubernetes Service 서브넷 | `10.96.0.0` |

---

## 🖼️ VKSm Extension 이미지 다운로드 & 업로드

VKS Cluster Management(VKSm) Extension 이미지를 Air-Gapped 환경에 반입할 때 사용합니다.

> **Extension 버전:** `9.0.2-0-25145732`  
> **Source Registry:** `projects.packages.broadcom.com/vsphere/vksm`  
> **요구사항:** `imgpkg` (https://carvel.dev), `tar`

### download-extensions.sh — 이미지 다운로드 (인터넷 연결 환경)

Public Registry에서 VKSm Extension 이미지 28개를 tarball로 묶어 저장합니다.

```bash
# 실행 (인터넷 연결 환경에서 실행)
bash download-extensions.sh

# 출력물
# ./vksm-extensions/    - 개별 이미지 tar 파일 디렉토리
# ./extensions.tar.gz   - 최종 번들 tarball (upload 스크립트에서 사용)
```

**포함 Extension 목록 (버전: 9.0.2-0-25145732):**

| Extension | 이미지 |
|-----------|--------|
| agent-updater | agent-updater, agentupdater-workload, manifest |
| cluster-health-extension | manager, manifest |
| cluster-sync-extension | cluster-sync-extension, manifest |
| extension-manager | extension-manager, manifest |
| extension-updater | extension-updater, manifest |
| gatekeeper | gatekeeper, gatekeeper-operator, manifest |
| intent-agent | intent-agent, manifest |
| policy-insight-extension | policy-insight-extension, manifest |
| fleet-mgmt | policy-sync-extension, manifest |
| tmc-bootstrapper | manager, manifest |
| tmc-observer | tmc-observer, logs-collector, manifest |
| dataprotection | extension, manifest |

### upload-extensions.sh — 이미지 업로드 (Offline 환경)

`download-extensions.sh`로 생성한 tarball을 Private Harbor Registry에 업로드합니다.

```bash
# 사용법
./upload-extensions.sh <tarball_path> <destination_registry>

# 예시
./upload-extensions.sh extensions.tar.gz <harbor-fqdn>/vksm

# 실행 전 Harbor 로그인
docker login <harbor-fqdn>
```

---

## 📦 Supervisor Service 패키지 (`Supervisor/`)

vCenter Supervisor Services 등록 시 사용하는 패키지 YAML 및 Data Values 파일입니다.

| 서비스 | Package YAML | Data Values |
|--------|-------------|-------------|
| **Harbor** | `Harbor/legacy-harbor-svs-v2.14.2+vmware.2-vks.1-25220498.yml` | `Harbor/Harborharbor-data-values-v2.14.2.yml` |
| **Contour** | `Contour/contour-service-v1.32.0.yml` | `Contour/contour-data-values-v1.32.yml` |
| **VKS** | `VKS/3.5.0-package.yaml` / `VKS/3.6.0-package.yaml` | - |
| **LCI** | `LCI/lci-svs-9.0.2.yaml` | - |

> 📌 Air-Gapped 환경에서는 각 YAML 내 `imgpkgBundle.image` 값을 Private Harbor 주소로 수정 후 등록합니다.  
> 상세 절차: [`offline-prep.md` — 1-4 Supervisor Services 이미지 이전](./offline-prep.md#1-4-supervisor-services-이미지-이전-private-registry-리로케이션)

---

## 🩺 Daily Health Check (`heath-check/`)

VKS 환경 일일 점검용 스크립트 모음입니다.

| 스크립트 | 점검 대상 | 실행 방법 |
|---------|---------|---------|
| `avi-hc.sh` | NSX ALB Virtual Service / Service Engine 상태 | `bash avi-hc.sh` (대화형) |
| `service-hc.sh` | Supervisor External LB 서비스 / Harbor Registry | `bash service-hc.sh` |
| `sup-hc.sh` | Supervisor 노드 / 파드 / PVC / LB / VKS 클러스터 상태 | `bash sup-hc.sh` |
| `vcfa-hc.sh` | VCFA `/status` 엔드포인트 서비스 상태 | `VCFA_HOST=<fqdn> bash vcfa-hc.sh` |

예상 출력 샘플: [`heath-check/SAMPLE_OUTPUT.md`](./heath-check/SAMPLE_OUTPUT.md)

```bash
# 전체 일괄 점검 (Supervisor 컨텍스트 설정 후 실행)
for script in service-hc sup-hc; do
  echo "===== ${script}.sh ====="
  bash heath-check/${script}.sh
done
VCFA_HOST=<vcfa-fqdn> bash heath-check/vcfa-hc.sh
bash heath-check/avi-hc.sh
```

---

## 🔗 참고 링크

| 문서 | URL |
|------|-----|
| VCF CLI Offline 설치 | https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-0/building-your-cloud-applications/getting-started-with-the-tools-for-building-applications/installing-and-using-vcf-cli-v9/installing-the-vcf-cli-in-internet-restricted-environments(2).html |
| Supervisor Services → Private Registry | https://techdocs.broadcom.com/us/en/vmware-cis/vsphere/vsphere-supervisor/8-0/vsphere-supervisor-services-and-workloads-8-0/deploying-supervisor-services-from-a-private-container-image-registry/relocate-supervisor-services-to-a-private-registry.html |
| VKR Local Content Library (Air-Gapped) | https://techdocs.broadcom.com/us/en/vmware-cis/vsphere/vsphere-supervisor/8-0/using-tkg-service-with-vsphere-supervisor/administering-kubernetes-releases-for-tkg-service-clusters/create-a-local-content-library-for-air-gapped-cluster-provisioning.html |
| Standard Packages → Harbor | https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-consumption/latest/managing-vsphere-kuberenetes-service-clusters-and-workloads/using-private-registries-with-tkg-service-clusters/push-standard-packages-to-a-private-harbor-registry.html |
| VKSm Air-Gapped 환경 구성 | https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-consumption/latest/managing-vks-clusters-with-vks-cluster-management/installation-and-enablement-of-vks-cluster-management/enabling-vks-cluster-management-in-an-airgapped-environment-without-fds.html |
| Bitnami Harbor VM | https://docs.bitnami.com/virtual-machine/infrastructure/harbor/ |
| Carvel Tools (imgpkg) | https://carvel.dev |
