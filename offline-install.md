# VMware VCF VKS 9.0.2 — Offline 설치 순서 및 절차

> **대상 버전:** VCF 9.0.2 / VKS 3.5.0  
> **환경:** 인터넷 차단(Air-Gapped), Private Harbor Registry 사용  
> **최종 정리:** 2026-05-13  
> **사전 준비:** [offline-prep.md](./offline-prep.md) 참고

---

## 설치 흐름

```
[STEP 1]  Bastion VM 구성
    ↓
[STEP 2]  Harbor VM 배포 및 인증서 설정
    ↓
[STEP 3]  vCenter 사전 구성 (Storage Policy / Content Library / Network)
    ↓
[STEP 4]  Supervisor 배포 및 설정
    ↓
[STEP 5]  VCF Context 등록
    ↓
[STEP 6]  Supervisor Services 등록 (VKS / Management Proxy)
    ↓
[STEP 7]  Standard Packages 업로드
    ↓
[STEP 8]  VCFA Tenant 구성 (Region / Quota / IP Space / Gateway)
    ↓
[STEP 9]  VKSm Extension 업로드
    ↓
[STEP 10] VKSm Repository 업데이트
    ↓
[STEP 11] Private Registry 인증서 등록
    ↓
[STEP 12] AddonRepository 업데이트 (Supervisor)
    ↓
[STEP 13] vSphere Namespace 생성
    ↓
[STEP 14] VKS 워크로드 클러스터 배포
```

---

## STEP 1. Bastion VM 구성

Offline 환경의 중계 노드. 모든 CLI 도구 및 이미지를 이 VM에서 관리.

```bash
# kubectl 설치
install ./kubectl /usr/local/bin/kubectl
kubectl version --client

# VCF CLI 설치
tar -xzf vcf-cli_linux_amd64_9_0_2.tar.gz
install ./vcf /usr/local/bin/vcf
vcf version

# VCF CLI Plugin Bundle 업로드 (Harbor에 먼저 올린 후)
docker login <harbor-fqdn> --tls-verify=false
vcf config cert add --host <harbor-fqdn> --ca-certificate harbor-ca.crt
vcf plugin upload-bundle --tar /tmp/FILE-NAME.tar.gz \
  --to-repo <harbor-fqdn>/vcf_cli/plugins
vcf plugin source update default \
  --uri <harbor-fqdn>/vcf_cli/plugins/plugin-inventory:latest
vcf plugin clean && vcf plugin list

# ArgoCD CLI 설치
install ./argocd /usr/local/bin/argocd

# Velero CLI 설치
install ./velero /usr/local/bin/velero

# Carvel tools 설치 (imgpkg, kapp, kbld, kctrl, ytt)
install ./imgpkg  /usr/local/bin/imgpkg
install ./kapp    /usr/local/bin/kapp
install ./kbld    /usr/local/bin/kbld
install ./kctrl   /usr/local/bin/kctrl
install ./ytt     /usr/local/bin/ytt
```

---

## STEP 2. Harbor VM 배포 및 구성

### 2-1. VM 배포

- Bitnami Harbor OVA로 VM 배포
- 배포 전 디스크 구성 조정:
  - Disk 1: 100GB (OS)
  - Disk 2: 100GB (Registry Storage)

### 2-2. Harbor Registry 스토리지 마운트

```bash
sudo fdisk /dev/sdb         # n → p → 1 → default → default → w
sudo mkfs.ext4 /dev/sdb1
sudo mount /dev/sdb1 /bitnami/harbor-registry/storage
chown harbor:harbor /bitnami/harbor-registry/storage

# /etc/fstab 등록 (재부팅 후 자동 마운트)
echo "/dev/sdb1  /bitnami/harbor-registry/storage  ext4  defaults  0  2" \
  | sudo tee -a /etc/fstab
```

### 2-3. SSH 활성화 (Bitnami 기본: 비밀번호 인증 비활성화)

```bash
sudo sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' \
  /etc/ssh/sshd_config
sudo rm -f /etc/ssh/sshd_not_to_be_run
sudo systemctl enable sshd
sudo systemctl restart sshd
```

### 2-4. TLS 인증서 생성

```bash
# Root CA 생성
openssl genrsa -out admin-ca.key 4096
openssl req -x509 -new -nodes -sha512 -days 3650 \
  -subj "/C=US/ST=CA/L=PaloAlto/O=VCF/OU=Supervisor/CN=Harbor" \
  -key admin-ca.key -out admin-ca.crt

# Harbor 서버 키/CSR 생성
openssl genrsa -out harbor.key 4096
openssl req -sha512 -new \
  -subj "/C=US/ST=CA/L=PaloAlto/O=VCF/OU=Supervisor/CN=mgd-harbor.psolab.local" \
  -key harbor.key -out harbor.csr

# SAN 확장 파일 생성
cat > v3.ext <<-EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage=digitalSignature,nonRepudiation,keyEncipherment,dataEncipherment
extendedKeyUsage=serverAuth
subjectAltName=@alt_names

[alt_names]
DNS.1=mgd-harbor.psolab.local
IP.1=10.10.10.1
EOF

# Harbor 인증서 서명
openssl x509 -req -sha512 -days 365 \
  -extfile v3.ext \
  -CA admin-ca.crt -CAkey admin-ca.key -CAcreateserial \
  -in harbor.csr -out harbor.crt

# 생성 파일 확인
ls -la harbor.crt harbor.key harbor.csr admin-ca.crt admin-ca.key
```

### 2-5. Harbor 인증서 적용 및 재시작

```bash
# nginx 인증서 교체
cat ./harbor.key > /opt/bitnami/nginx/conf/bitnami/certs/server.key
cat ./harbor.crt > /opt/bitnami/nginx/conf/bitnami/certs/server.crt

# Harbor 서비스 재시작
sudo /opt/bitnami/ctlscript.sh restart
```

---

## STEP 3. vCenter 사전 구성

| 작업 | 설명 |
|------|------|
| **Storage Policy** | vSphere Namespace용 스토리지 정책 생성 |
| **Content Library** | VKR (VM Release) OVA 템플릿 업로드용 Library 생성 |
| **VKR 업로드** | 각 K8s 버전 VKR을 Content Library에 업로드 |
| **Network Connectivity Profile** | VPC External IP Blocks / Private TGW IP Blocks 구성 |
| **vSphere Zone** | Multi-Zone 구성 시 Zone 정의 |

---

## STEP 4. Supervisor 배포 및 설정

```bash
# Multi-Zonal Supervisor 구성 시 (API Call 방식)
# → JSON 스크립트를 vCenter API로 호출

# Supervisor VM root 비밀번호 확인
ssh root@<vcenter-fqdn>
python3 /usr/lib/vmware-wcp/decryptK8spwd.py

# Supervisor 상태 검증 (Supervisor VM 내부)
kubectl get nodes
kubectl get pods -A
```

**Supervisor 배포 후 설정:**

1. **Content Library 연결**  
   `Configure → General → Kubernetes Service → Content Library` 에서 VKR Library 추가

2. **Harbor CA 인증서 등록**  
   `Configure → General → Kubernetes Service → Add Registry`  
   → Harbor FQDN + `admin-ca.crt` 등록

---

## STEP 5. VCF Context 등록

```bash
# vSphere SSO 방식
vcf context create <context-name> \
  --endpoint <supervisor_VIP> \
  -u administrator@vsphere.local \
  --auth-type basic \
  --ca-certificate ./cert_file

# Workload Cluster 접근 Context
vcf context create <context_name> \
  --endpoint <supervisor_VIP> \
  --workload-cluster-name <workload_cluster> \
  --workload-cluster-namespace <workload_namespace> \
  -u <user> \
  --insecure-skip-tls-verify

# VCFA (VCF Automation) 방식
vcf context create <context_name> \
  --type cci \
  --endpoint <VCFA_FQDN> \
  --tenant-name <TENANT> \
  --ca-certificate ./fleet.pem \
  --api-token <TOKEN>

vcf context use <context_name>:<namespace>:<project>
vcf cluster register-vcfa-jwt-authenticator <kubernetes-cluster-name>
vcf cluster kubeconfig get <kubernetes-cluster-name>
```

---

## STEP 6. Supervisor Services 등록

### 6-1. VKS Supervisor Service

- Broadcom Support Portal에서 다운로드한 Packages 파일 + Data Values 파일 업로드
- Supervisor Services 이미지 (tar)를 Harbor에 push 후 등록

### 6-2. Management Proxy Supervisor Service

```yaml
# Data Values 예시
vksmAPIPort: 10094
vksmHTTPRemoteEndpoint:
  host: <VCFA_FQDN>
  port: 443
```

---

## STEP 7. VKS Standard Packages 업로드 (Harbor)

```bash
# Harbor에 Standard Packages 이미지 업로드
imgpkg copy \
  --tar ./vks-standard-packages:3.5.0-20251022.tar \
  --to-repo <harbor-fqdn>/packages/2025.10.22/vks-standard-packages \
  --registry-ca-cert-path ./tls.crt \
  --registry-username='admin' \
  --registry-password='<password>'

# 업로드 확인
imgpkg describe \
  -b <harbor-fqdn>/packages/2025.10.22/vks-standard-packages \
  --registry-ca-cert-path ./tls.crt
```

---

## STEP 8. VCFA Tenant 구성

| 순서 | 작업 |
|------|------|
| 1 | Create Region |
| 2 | Create Region Quota |
| 3 | Create IP Space |
| 4 | Create Provider Gateway |

---

## STEP 9. VKSm Extension 업로드

```bash
# upload-extensions.sh 실행
bash upload-extensions.sh
```

---

## STEP 10. VKSm Repository 업데이트

```bash
# VCFA에 SSH 접속
ssh vmware-system-user@<vcfa-fqdn>

# Service Account Token 및 Primary VIP 확인
K8S_TOKEN=$(kubectl get secrets synthetic-checker-krp \
  -n vmsp-platform \
  -ojsonpath='{.data.token}' | base64 -d)

PRIMARY_VIP=$(kubectl get gateway/vmsp-gateway \
  -n istio-ingress \
  -ojson | jq -j '.status.addresses[0].value')

# VKSm Extension Registry 업데이트
curl -k -XPOST \
  -H "Authorization: Bearer $K8S_TOKEN" \
  "http://$PRIMARY_VIP:30005/webhooks/vmsp-platform/kubectl/patch-merge" \
  -d '{
    "name": "vcfa-bundle",
    "namespace": "prelude",
    "type": "packageDeployment",
    "patch": {
      "spec": {
        "values": {
          "vksm": {
            "extensionsRegistry": "<harbor-fqdn>/vksm"
          }
        }
      }
    }
  }'
```

---

## STEP 11. Private Registry (Harbor) CA 인증서 등록

```bash
# Harbor CA 인증서를 VCFA로 복사
scp tls.crt vmware-system-user@<vcfa-fqdn>:/tmp/

# VCFA에서 Secret 생성 및 라벨 적용
kubectl create secret generic <harbor-name> \
  --from-file=ca.crt=./tls.crt \
  --namespace=vmsp-platform

kubectl label secret <harbor-name> \
  trust.vmsp.vmware.com/bundle=platform-trust \
  --namespace=vmsp-platform
```

---

## STEP 12. AddonRepository 업데이트 (Supervisor)

```bash
# addonrepository-override.yaml 적용
# 주요 수정 항목:
#   metadata.name: default-addonrepository-override
#   imageURL: "<harbor-fqdn>/packages/2025.10.22/vks-standard-packages:3.5.0-20251022"
#   version: 3.5.0-20251022

kubectl apply -f addonrepository-override.yaml

# AddonRepositoryInstall 업데이트
kubectl edit addonrepositoryinstall default-addon-repo-install \
  -n vmware-system-vks-public
# → addonRepositoryRef.name: default-addonrepository-override
```

---

## STEP 13. vSphere Namespace 생성

1. vSphere Client → `Workload Management → Namespaces → New Namespace`
2. Supervisor 및 Storage Policy 선택
3. 네트워크(VPC 구성) 연결
4. 권한(Permissions) 설정 — 관리자 계정 바인딩

---

## STEP 14. VKS 워크로드 클러스터 배포

```bash
# VCF CLI로 클러스터 생성 (예시)
vcf cluster create \
  --name <cluster-name> \
  --namespace <vsphere-namespace> \
  --k8s-version v1.32.3 \
  --control-plane-count 3 \
  --worker-count 3 \
  --storage-class <storage-class-name>

# 또는 YAML 매니페스트로 직접 apply
kubectl apply -f vks-cluster.yaml -n <vsphere-namespace>

# Kubeconfig 획득
vcf cluster kubeconfig get <cluster-name>
```

---

## 참고 링크

| 문서 | URL |
|------|-----|
| VCF CLI 설치 (인터넷 연결) | https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-0/building-your-cloud-applications/getting-started-with-the-tools-for-building-applications/installing-and-using-vcf-cli-v9/installing-the-vcf-cli-in-internet-connected-environments/install-the-vcf-cli(3)/install-vcf-cli-plugins.html |
| VCF CLI 설치 (Offline) | https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-0/building-your-cloud-applications/getting-started-with-the-tools-for-building-applications/installing-and-using-vcf-cli-v9/installing-the-vcf-cli-in-internet-restricted-environments(2).html |
| VKSm Air-Gapped 환경 구성 | https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-consumption/latest/managing-vks-clusters-with-vks-cluster-management/installation-and-enablement-of-vks-cluster-management/enabling-vks-cluster-management-in-an-airgapped-environment-without-fds.html |
| Carvel Tools | https://carvel.dev |
| Bitnami Harbor | https://bitnami.com/stack/harbor/virtual-machine |
