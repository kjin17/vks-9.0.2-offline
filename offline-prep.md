# VMware VCF VKS 9.0.2 — Offline 설치 준비 (다운로드 목록)

> **대상 버전:** VCF 9.0.2 / VKS 3.5.0  
> **환경:** 인터넷 차단(Air-Gapped), Private Harbor Registry 사용  
> **최종 정리:** 2026-05-13

---

## 목차

1. [사전 다운로드 목록](#1-사전-다운로드-목록)
   - [1-1. VKR — Local Content Library 구성](#1-1-vkr-vm-release--local-content-library-구성-air-gapped)
   - [1-2. VCF CLI Plugin Bundle 생성](#1-2-vcf-cli-plugin-bundle-생성-인터넷-환경에서-실행)
   - [1-3. Supervisor Services 이미지 tar 추출](#1-3-supervisor-services-이미지-tar-추출-imgpkg-사용)
   - [1-4. Standard Packages 다운로드](#1-4-standard-packages-다운로드-public-registry--tarball)
   - [1-5. VKSm Extension 이미지 다운로드](#1-5-vksm-extension-이미지-다운로드)

---

## 1. 사전 다운로드 목록

> 인터넷 연결 환경(Bastion 또는 별도 PC)에서 미리 다운로드해 Offline 환경으로 반입

| # | 컴포넌트 | 버전 / 파일명 | 다운로드 위치 |
|---|---------|--------------|--------------|
| 1 | **Harbor VM Template** | bitnami-harbor-2.14.2-r0-debian-12-amd64.ova | https://bitnami.com/stack/harbor/virtual-machine |
| 2 | **Avi Controller** | 31.1.2-P21 | Broadcom Support Portal |
| 3 | **VCF CLI** | vcf-cli_linux_amd64_9_0_2.tar.gz | https://packages.broadcom.com/artifactory/vcf-distro/vcf-cli/ |
| 4 | **VCF CLI Plugin Bundle** | FILE-NAME.tar.gz | VCF plugin download 명령어로 다운로드 |
| 5 | **kubectl** | 최신 stable | https://dl.k8s.io/release/stable.txt |
| 6 | **VKR (VM Release) Images** | K8s 각 버전별 OVA | https://wp-content.vmware.com/v2/latest/ |
| 7 | **VKS Standard Packages** | vks-standard-packages:3.5.0-20251022.tar | `imgpkg copy` 명령으로 생성 (아래 참고) |
| 8 | **Supervisor Services Images** | 각 서비스별 tar | `imgpkg copy` 명령으로 생성 (아래 참고) |
| 9 | **Carvel Tools** | imgpkg / kapp / kbld / kctrl / ytt | https://carvel.dev |
| 10 | **VKSm Extension** | 확장 이미지 번들 | [`download-extensions.sh`](./download-extensions.sh) 실행 |
| 11 | **Docker** | 최신 stable | https://docs.docker.com/engine/install/ |
| 12 | **Helm** | (선택) | https://helm.sh/docs/intro/install/ |
| 13 | **ArgoCD CLI** | 최신 stable | https://argo-cd.readthedocs.io |
| 14 | **Velero CLI** | 최신 stable | https://velero.io/docs/ |
| 15 | **Keycloak** | (선택, OIDC 연동 시) | https://www.keycloak.org/downloads |
| 16 | **Multi-Zonal Supervisor JSON** | (선택, Multi-Zone 구성 시) | enable-wcp.sh |

---

### 1-1. VKR (VM Release) — Local Content Library 구성 (Air-Gapped)

> 📌 참고: [Create a Local Content Library for Air-Gapped Cluster Provisioning](https://techdocs.broadcom.com/us/en/vmware-cis/vsphere/vsphere-supervisor/8-0/using-tkg-service-with-vsphere-supervisor/administering-kubernetes-releases-for-tkg-service-clusters/create-a-local-content-library-for-air-gapped-cluster-provisioning.html)

#### VKS 3.5.0 기준 지원 Kubernetes 버전

| 채널 | 지원 버전 |
|------|----------|
| v1.31 | v1.31.4 / v1.31.7 / v1.31.11 |
| v1.32 | v1.32.0 / v1.32.3 / v1.32.7 |
| v1.33 | v1.33.1 / v1.33.3 |
| v1.34 | v1.34.1 / v1.34.2 |

#### VKR OVA 다운로드

각 버전별로 아래 4개 파일을 다운로드 (보안 정책 적용 시 4개 모두 필요):

| 파일 | 설명 |
|------|------|
| `photon-ova.ovf` | OVF 디스크립터 |
| `photon-ova-disk1.vmdk` | 디스크 이미지 |
| `photon-ova.cert` | 서명 인증서 (보안 정책 적용 시 필수) |
| `photon-ova.mf` | 매니페스트 (보안 정책 적용 시 필수) |

```
# 다운로드 URL
https://wp-content.vmware.com/v2/latest/

# 버전 디렉토리 예시
ob-XXXXXXXX-photon-3-k8s-v1.32.3---vmware.1-tkg.1.XXXXXXX
```

#### Local Content Library 생성 절차

1. vSphere Client → **Content Library → Create**
2. 이름 입력 (예: `TKr-local`) → Next
3. **Local content library** 선택 → Next
4. 보안 정책: **Apply Security Policy → OVF default policy** 선택 → Next
5. Storage 선택 → Finish

#### VKR OVA 임포트

1. 생성한 Content Library 선택
2. **Actions → Import Item → Local File → Upload Files**
3. `photon-ova.ovf` + `photon-ova-disk1.vmdk` 2개 파일 선택
4. **Destination Item name** = 다운로드 폴더명과 **정확히 일치**시킬 것  
   (예: `photon-3-k8s-v1.32.3---vmware.1-tkg.1.XXXXXXX`)  
   > ⚠️ 이름 불일치 시 Supervisor가 TKG Release를 인식하지 못함
5. Import → Recent Tasks에서 `Fetch Content of a Library Item` 완료 확인

---

### 1-2. VCF CLI Plugin Bundle 생성 (인터넷 환경에서 실행)

```bash
# Plugin Bundle을 tar로 내보내기
vcf plugin download-bundle --to-tar /tmp/FILE-NAME.tar.gz
```

> 📌 참고:
> - [VCF CLI 설치 (인터넷 연결)](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-0/building-your-cloud-applications/getting-started-with-the-tools-for-building-applications/installing-and-using-vcf-cli-v9/installing-the-vcf-cli-in-internet-connected-environments/install-the-vcf-cli(3)/install-vcf-cli-plugins.html)
> - [VCF CLI 설치 (Offline)](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-0/building-your-cloud-applications/getting-started-with-the-tools-for-building-applications/installing-and-using-vcf-cli-v9/installing-the-vcf-cli-in-internet-restricted-environments(2).html)

---

### 1-3. Supervisor Services 이미지 tar 추출 (imgpkg 사용)

> 각 Supervisor Service의 Packages 파일 내 `images:` 항목을 참고하여 이미지 repo 확인 후 pull

```bash
# Harbor
imgpkg copy -b projects.packages.broadcom.com/vsphere/supervisor/harbor-service/2.14.2_vmware.2-vks.1 \
  --to-tar=./harbor_v2.14.2.tar

# ArgoCD, Contour, VKS, Management Proxy도 동일 방식으로 추출
# (각 패키지의 images: 항목에서 이미지 repo 주소 확인)
```

**다운로드 대상 Supervisor Services:**
- Harbor
- ArgoCD
- Contour
- VKS
- Management Proxy

---

### 1-4. Standard Packages 다운로드 (Public Registry → Tarball)

> 📌 참고: [Push Standard Packages to a Private Harbor Registry](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-consumption/latest/managing-vsphere-kuberenetes-service-clusters-and-workloads/using-private-registries-with-tkg-service-clusters/push-standard-packages-to-a-private-harbor-registry.html)

**Prerequisites:**
- Carvel `imgpkg` 설치 완료
- Docker 클라이언트 설치 및 Harbor CA 인증서 적용 완료
- Harbor에 `packages` 프로젝트(Public) 생성 완료

#### 방법 1: Tarball 경유 (Air-Gapped 권장)

```bash
# Step 1: Public Registry에서 tarball로 pull (인터넷 연결 환경에서 실행)
imgpkg copy \
  --bundle projects.packages.broadcom.com/vsphere/supervisor/packages/2025.1.7/vks-standard-packages:v2025.1.7 \
  --to-tar ./vks-standard-packages-v2025.1.7.tar

# Step 2: tarball을 Offline 환경으로 반입 후 Harbor에 push
imgpkg copy \
  --tar ./vks-standard-packages-v2025.1.7.tar \
  --to-repo <harbor-fqdn>/packages/vks-standard-packages \
  --registry-ca-cert-path ./admin-ca.crt
```

#### 방법 2: 직접 복사 (인터넷 ↔ Harbor 동시 접근 가능한 환경)

```bash
imgpkg copy \
  -b projects.packages.broadcom.com/vsphere/supervisor/packages/2025.1.7/vks-standard-packages:v2025.1.7 \
  --to-repo <harbor-fqdn>/packages/vks-standard-packages \
  --registry-ca-cert-path ./admin-ca.crt
```

#### 업로드 검증

```bash
# 1. Package bundle을 로컬 폴더로 pull
imgpkg pull \
  -b <harbor-fqdn>/packages/vks-standard-packages:v2025.1.7 \
  -o /tmp/vks-standard-packages

# 2. 포함된 이미지 목록 확인
cat /tmp/vks-standard-packages/.imgpkg/images.yml

# 3. 개별 이미지 docker pull로 최종 확인
docker pull <harbor-fqdn>/packages/vks-standard-packages@sha256:<digest>
```

> ⚠️ `--to-repo` 경로의 Harbor 프로젝트는 반드시 **Public** 으로 설정해야 Supervisor가 인증 없이 접근 가능합니다.

---

### 1-5. VKSm Extension 이미지 다운로드

> **버전:** `9.0.2-0-25145732`  
> **스크립트:** [`download-extensions.sh`](./download-extensions.sh)

```bash
# download-extensions.sh 실행 (인터넷 연결 환경에서 실행)
bash download-extensions.sh

# 스크립트 내 주요 경로 예시 (버전: 9.0.2-0-25145732)
# /extensions/9.0.2-0-25145732/agent-updater/agent-updater:latest
# /extensions/9.0.2-0-25145732/extension-manager/extension-manager:latest
# /extensions/9.0.2-0-25145732/gatekeeper:latest
# ... 외 25개 extension 이미지
```

> 📌 참고: [Enabling VKS Cluster Management in an Air-Gapped Environment Without FDS](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-consumption/latest/managing-vks-clusters-with-vks-cluster-management/installation-and-enablement-of-vks-cluster-management/enabling-vks-cluster-management-in-an-airgapped-environment-without-fds.html)

---

## 참고 링크

| 문서 | URL |
|------|-----|
| VCF CLI 설치 (인터넷 연결) | https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-0/building-your-cloud-applications/getting-started-with-the-tools-for-building-applications/installing-and-using-vcf-cli-v9/installing-the-vcf-cli-in-internet-connected-environments/install-the-vcf-cli(3)/install-vcf-cli-plugins.html |
| VCF CLI 설치 (Offline) | https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-0/building-your-cloud-applications/getting-started-with-the-tools-for-building-applications/installing-and-using-vcf-cli-v9/installing-the-vcf-cli-in-internet-restricted-environments(2).html |
| VKSm Air-Gapped 환경 구성 | https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-consumption/latest/managing-vks-clusters-with-vks-cluster-management/installation-and-enablement-of-vks-cluster-management/enabling-vks-cluster-management-in-an-airgapped-environment-without-fds.html |
| Local Content Library (Air-Gapped) | https://techdocs.broadcom.com/us/en/vmware-cis/vsphere/vsphere-supervisor/8-0/using-tkg-service-with-vsphere-supervisor/administering-kubernetes-releases-for-tkg-service-clusters/create-a-local-content-library-for-air-gapped-cluster-provisioning.html |
| Standard Packages → Harbor | https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-consumption/latest/managing-vsphere-kuberenetes-service-clusters-and-workloads/using-private-registries-with-tkg-service-clusters/push-standard-packages-to-a-private-harbor-registry.html |
| Carvel Tools | https://carvel.dev |
| Bitnami Harbor | https://bitnami.com/stack/harbor/virtual-machine |
