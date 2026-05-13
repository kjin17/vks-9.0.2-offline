# VMware VCF VKS 9.0.2 — Offline 설치 준비 (다운로드 목록)

> **대상 버전:** VCF 9.0.2 / VKS 3.5.0  
> **환경:** 인터넷 차단(Air-Gapped), Private Harbor Registry 사용  
> **최종 정리:** 2026-05-13

---

## 목차

1. [사전 다운로드 목록](#1-사전-다운로드-목록)
   - [1-1. Harbor VM (Bitnami) 배포 및 서비스 관리](#1-1-harbor-vm-bitnami--배포-및-서비스-관리)
   - [1-2. VKR — Local Content Library 구성](#1-2-vkr-vm-release--local-content-library-구성-air-gapped)
   - [1-3. VCF CLI Plugin Bundle 다운로드 및 업로드](#1-3-vcf-cli-plugin-bundle-다운로드-및-업로드-offline-환경)
   - [1-4. Supervisor Services 이미지 이전 (Private Registry 리로케이션)](#1-4-supervisor-services-이미지-이전-private-registry-리로케이션)
   - [1-5. Standard Packages 다운로드](#1-5-standard-packages-다운로드-public-registry--tarball)
   - [1-6. VKSm Extension 이미지 다운로드](#1-6-vksm-extension-이미지-다운로드)

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
| 13 | **ArgoCD CLI** | 최신 stable | roadcom Support Portal  |
| 14 | **Velero CLI** | 최신 stable | https://velero.io/docs/ |
| 15 | **Keycloak** | (선택, OIDC 연동 시) | https://www.keycloak.org/downloads |
| 16 | **Multi-Zonal Supervisor JSON** | (선택, Multi-Zone 구성 시) | enable-wcp.sh |

---

### 1-1. Harbor VM (Bitnami) — 배포 및 서비스 관리

> 📌 참고: [Bitnami Harbor VM — Start or Stop Services](https://docs.bitnami.com/virtual-machine/infrastructure/harbor/administration/control-services/)

#### VM 사양 및 디스크 구성

| 항목 | 값 |
|------|----|
| **OVA** | bitnami-harbor-2.14.2-r0-debian-12-amd64.ova |
| **Disk 1** | 100GB (OS + Harbor 앱) |
| **Disk 2** | 100GB (Registry Storage — 별도 마운트 필요) |
| **기본 포트** | HTTP: 80 / HTTPS: 443 |
| **기본 계정** | `admin` / 최초 부팅 시 콘솔에서 확인 |

#### 서비스 제어 (`ctlscript.sh`)

> Bitnami VM은 `/opt/bitnami/ctlscript.sh` 로 모든 서비스를 제어합니다.

```bash
# 전체 서비스 상태 확인
sudo /opt/bitnami/ctlscript.sh status

# 전체 서비스 시작
sudo /opt/bitnami/ctlscript.sh start

# 전체 서비스 중지
sudo /opt/bitnami/ctlscript.sh stop

# 전체 서비스 재시작
sudo /opt/bitnami/ctlscript.sh restart

# 개별 서비스 재시작 (nginx만)
sudo /opt/bitnami/ctlscript.sh restart nginx
```

#### 주요 서비스 구성

| 서비스 | 역할 |
|--------|------|
| `nginx` | Harbor 프론트엔드 프록시 (80/443) |
| `harbor-core` | Harbor 핵심 API 서버 |
| `harbor-jobservice` | 이미지 복제/스캔 작업 처리 |
| `harbor-registry` | 컨테이너 이미지 스토리지 |
| `postgresql` | Harbor 메타데이터 DB |
| `redis` | Harbor 캐시/세션 |

#### Registry Storage 마운트

```bash
# 2번째 디스크 파티션 생성
sudo fdisk /dev/sdb   # n → p → 1 → default → default → w

# 포맷 및 마운트
sudo mkfs.ext4 /dev/sdb1
sudo mount /dev/sdb1 /bitnami/harbor-registry/storage
sudo chown harbor:harbor /bitnami/harbor-registry/storage

# 재부팅 후 자동 마운트 (fstab 등록)
echo "/dev/sdb1  /bitnami/harbor-registry/storage  ext4  defaults  0  2" \
  | sudo tee -a /etc/fstab
```

#### SSH 활성화 (Bitnami 기본값: 비밀번호 인증 비활성화)

```bash
sudo sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo rm -f /etc/ssh/sshd_not_to_be_run
sudo systemctl enable sshd && sudo systemctl restart sshd
```

#### TLS 인증서 교체 (Custom CA)

```bash
# nginx 인증서 경로
/opt/bitnami/nginx/conf/bitnami/certs/server.key
/opt/bitnami/nginx/conf/bitnami/certs/server.crt

# 인증서 교체
cat ./harbor.key > /opt/bitnami/nginx/conf/bitnami/certs/server.key
cat ./harbor.crt > /opt/bitnami/nginx/conf/bitnami/certs/server.crt

# nginx 재시작
sudo /opt/bitnami/ctlscript.sh restart nginx
```

#### 로그 위치

| 서비스 | 로그 경로 |
|--------|----------|
| nginx | `/opt/bitnami/nginx/logs/error.log` |
| harbor-core | `/opt/bitnami/harbor/common/config/log/` |
| postgresql | `/opt/bitnami/postgresql/logs/` |

---

### 1-2. VKR (VM Release) — Local Content Library 구성 (Air-Gapped)

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

### 1-3. VCF CLI Plugin Bundle 다운로드 및 업로드 (Offline 환경)

> 📌 참고:
> - [VCF CLI 설치 (인터넷 연결)](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-0/building-your-cloud-applications/getting-started-with-the-tools-for-building-applications/installing-and-using-vcf-cli-v9/installing-the-vcf-cli-in-internet-connected-environments/install-the-vcf-cli(3)/install-vcf-cli-plugins.html)
> - [VCF CLI 설치 (Offline)](https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-0/building-your-cloud-applications/getting-started-with-the-tools-for-building-applications/installing-and-using-vcf-cli-v9/installing-the-vcf-cli-in-internet-restricted-environments(2).html)

> ⚠️ Private Registry는 **인증 없이 pull 가능하도록** 설정해야 합니다 (Public 프로젝트).

#### Step 1. VCF CLI 바이너리 설치 (인터넷 환경)

```bash
# VCF CLI 다운로드
wget https://packages.broadcom.com/artifactory/vcf-distro/vcf-cli/vcf-cli_linux_amd64_9_0_2.tar.gz

# 설치
tar -xzf vcf-cli_linux_amd64_9_0_2.tar.gz
install ./vcf /usr/local/bin/vcf
vcf version
```

#### Step 2. Plugin Bundle 다운로드 (인터넷 환경)

```bash
# 웹 연결 환경에서 사용 가능한 Plugin Group/Plugin 목록 확인
vcf plugin group search
vcf plugin search

# 옵션 A: 전체 Plugin Bundle 다운로드 (기본 Registry 전체)
vcf plugin download-bundle --to-tar /tmp/vcf-plugins-all.tar.gz

# 옵션 B: 특정 Plugin Group 최신으로 다운로드
vcf plugin download-bundle \
  --group vmware-vcfcli/essentials \
  --to-tar /tmp/vcf-plugins-essentials.tar.gz

# 옵션 C: 특정 Plugin Group 특정 버전으로 다운로드
vcf plugin download-bundle \
  --group vmware-vcfcli/essentials:v9.0.0 \
  --to-tar /tmp/vcf-plugins-essentials-v9.0.0.tar.gz

# 옵션 D: 여러 Plugin Group 버전 동시 다운로드
vcf plugin download-bundle \
  --group vcfcli/essentials:v4.0.0,vcfcli/essentials:v9.0.0 \
  --to-tar /tmp/vcf-plugins-multi.tar.gz
```

#### Step 3. Offline 환경으로 반입 후 Private Harbor에 업로드

```bash
# Harbor 로그인
docker login <harbor-fqdn>
# 또는 VCF CLI 인증서 방식
vcf config cert add --host <harbor-fqdn> --ca-certificate ./admin-ca.crt

# Plugin Bundle을 Private Harbor에 업로드
vcf plugin upload-bundle \
  --tar /tmp/vcf-plugins-all.tar.gz \
  --to-repo <harbor-fqdn>/vcf_cli/plugins
```

#### Step 4. CLI Plugin Source를 Private Harbor로 변경

```bash
# 기본 Plugin Source를 Private Harbor로 변경
vcf plugin source update default \
  --uri <harbor-fqdn>/vcf_cli/plugins/plugin-inventory:latest

# 플러그인 캐시 초기화 후 목록 확인
vcf plugin clean && vcf plugin list

# 필요한 Plugin 설치
vcf plugin install <plugin-name>
```

---

### 1-4. Supervisor Services 이미지 이전 (Private Registry 리로케이션)

> 📌 참고: [Relocate Supervisor Services to a Private Registry](https://techdocs.broadcom.com/us/en/vmware-cis/vsphere/vsphere-supervisor/8-0/vsphere-supervisor-services-and-workloads-8-0/deploying-supervisor-services-from-a-private-container-image-registry/relocate-supervisor-services-to-a-private-registry.html)

**Prerequisites:**
- Carvel `imgpkg` 설치 완료
- 대상 레지스트리(Harbor) 로그인 완료 (`docker login <harbor-fqdn>`)
- 각 Supervisor Service의 YAML 파일 (`Supervisor/` 폴더 내 작성 파일 참고)

> ⚠️ `imgpkg copy` 명령을 사용할 것. `push` / `pull` 은 참조 이미지 전체를 가져오지 않음.

#### 다운로드 대상 Supervisor Services

| 서비스 | Public Registry 이미지 | 서비스 YAML 위치 |
|---------|------------------------|------|
| **Harbor** | `projects.packages.broadcom.com/vsphere/supervisor/harbor-service/2.14.2/harbor:v2.14.2_vmware.2-vks.1` | `Supervisor/Harbor/` |
| **Contour** | `projects.packages.broadcom.com/vsphere/supervisor/contour/1.32.0/contour:v1.32.0_vmware.1-vks.1` | `Supervisor/Contour/` |
| **VKS 3.5.0** | `projects.packages.broadcom.com/vsphere/iaas/tkg-service/3.5.0/tkg-service:3.5.0` | `Supervisor/VKS/3.5.0-package.yaml` |
| **VKS 3.6.0** | `projects.packages.broadcom.com/vsphere/iaas/vsphere-kubernetes-service/3.6.0/vsphere-kubernetes-service:3.6.0` | `Supervisor/VKS/3.6.0-package.yaml` |
| **VKS 3.6.2** | `projects.packages.broadcom.com/vsphere/iaas/vsphere-kubernetes-service/3.6.2/vsphere-kubernetes-service:3.6.2` | `Supervisor/VKS/vks-3.6.2+v1.35.yaml` |
| **LCI** | `projects.packages.broadcom.com/vsphere/iaas/lci-service/9.0.2/lci-service:9.0.2-f943fb89` | `Supervisor/LCI/` |
| **ArgoCD** | `projects.packages.broadcom.com/vsphere/supervisor/argocd-service/1.1.0/argocd-service:v1.1.0_vmware.1` | `Supervisor/ArgoCD/supervisor-service-argocd-legacy-*.yml` |
| **Management Proxy 0.4.0** | `projects.packages.broadcom.com/vsphere/iaas/supervisor-management-proxy-service/0.4.0/supervisor-management-proxy-service:0.4.0` | `Supervisor/Management Proxy/` |
| **Secret Store** | `projects.packages.broadcom.com/vsphere/iaas/secret-store-service/9.0.0/secret-store-service:v9.0.0-c3eabdc` | `Supervisor/secret store/` |

> 💡 **Depot 방식 파일** (`depot.kube-system.svc/...`)은 FDS(Fleet Depot Service) 연결 환경 전용입니다.  
> Air-Gapped 환경에서는 위 표의 `projects.packages.broadcom.com` 주소를 사용하는 **Legacy/Public Registry** 파일로 작업하세요.
| **ArgoCD** | Broadcom Support Portal 에서 확인 | - |

#### Step 1. YAML에서 imgpkgBundle 이미지 주소 확인

```yaml
# 서비스 YAML 예시 (Contour)
template:
  spec:
    fetch:
      - imgpkgBundle:
          image: projects.registry.vmware.com/tkg/packages/standard/contour:v1.24.4_vmware.1-tkg.1
          # ↑ 이 image 값을 복사해서 아래 imgpkg copy 명령에 사용
```

#### Step 2. Public Registry → Tarball 다운로드 (인터넷 환경)

```bash
# Contour 예시
imgpkg copy \
  -b projects.registry.vmware.com/tkg/packages/standard/contour:v1.24.4_vmware.1-tkg.1 \
  --to-tar ./contour-v1.24.4.tar \
  --cosign-signatures

# Harbor 예시
imgpkg copy \
  -b projects.packages.broadcom.com/vsphere/supervisor/harbor-service/2.14.2_vmware.2-vks.1 \
  --to-tar ./harbor_v2.14.2.tar \
  --cosign-signatures

# VKS, LCI, Management Proxy도 동일 방식
# (YAML 내 imgpkgBundle.image 값 참고)
```

#### Step 3. Tarball → Private Harbor에 업로드 (Offline 환경)

```bash
# Harbor 로그인
docker login <harbor-fqdn>

# Contour 업로드
imgpkg copy \
  --tar ./contour-v1.24.4.tar \
  --to-repo <harbor-fqdn>/supervisor-services/contour \
  --cosign-signatures

# Harbor 서비스 업로드
imgpkg copy \
  --tar ./harbor_v2.14.2.tar \
  --to-repo <harbor-fqdn>/supervisor-services/harbor \
  --cosign-signatures

# 나머지 서비스도 동일 방식으로 업로드
```

#### Step 4. 서비스 YAML 내 image URL 수정

```yaml
# 변경 전 (Public Registry)
template:
  spec:
    fetch:
      - imgpkgBundle:
          image: projects.registry.vmware.com/tkg/packages/standard/contour:v1.24.4_vmware.1-tkg.1

# 변경 후 (Private Harbor)
template:
  spec:
    fetch:
      - imgpkgBundle:
          image: <harbor-fqdn>/supervisor-services/contour:v1.24.4_vmware.1-tkg.1
```

> 💡 `Supervisor/` 폴더 내 YAML 파일들에서 `imgpkgBundle.image` 항목을 Private Harbor 주소로 하나씩 수정한 후 vCenter에서 Supervisor Service로 등록하면 됩니다.

---

### 1-5. Standard Packages 다운로드 (Public Registry → Tarball)

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

### 1-6. VKSm Extension 이미지 다운로드

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
