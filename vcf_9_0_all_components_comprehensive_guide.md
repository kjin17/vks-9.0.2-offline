# VMware Cloud Foundation (VCF) 9.0+ 컴포넌트 아키텍처 모델

본 가이드는 Broadcom TechDocs의 **VMware Cloud Foundation (VCF) 9.0 및 이후 버전 설계 개념(Concepts)**의 15개 하위 페이지 내용을 기반으로, 임의 축소나 생략 없이 각 핵심 컴포넌트 모델별 특장점(Benefits)과 고려사항(Implications)을 테이블 형태로 완벽히 격리하여 정리한 최종 마크다운 문서입니다.

---

## 1. VCF Fleet 관리 배포 모델 (VCF Fleet Deployment Models)
VCF 9.0에서 새롭게 도입된 최상위 관리 프레임워크인 'Fleet'을 프라이빗 클라우드 인프라 전체에 어떻게 토폴로지화할 것인지 정의하는 컴포넌트입니다.

| Fleet 배포 디자인<br>(Deployment Design) | 상세 아키텍처 및 속성<br>(Attributes) | 주요 설계 목적 및 특징<br>(Benefits & Features) | 장애 영향 및 고려사항<br>(Implications & Events) |
| :--- | :--- | :--- | :--- |
| **1. 단일 사이트 최소 설치 모델<br>(Fleet in a Single Site with Minimal Footprint)** | • 단일 가용성 존(Single AZ) 또는 단일 리전 내 배치<br>• 가장 최소화된 물리적 하드웨어 랙 자원으로 구성<br>• 자원 효율성(Resource Efficiency) 극대화 지향 | • 제한된 하드웨어 리소스로도 최상위 Fleet 수준의 중앙 집중식 관리 프레임워크 구축 가능<br>• 에지(Edge) 인프라 또는 초기 투자 비용이 민감한 소규모 비즈니스에 최적화 | • 애플리케이션 레벨의 가용성 존(AZ) 수준 결함 허용(Fault Tolerance)을 보장하지 않음<br>• 물리 호스트 장애 발생 시, 복구는 개별 물리 부품과 플랫폼의 `vSphere HA` 재기동 메커니즘에만 전적으로 의존함 |
| **2. 단일 사이트 표준 모델<br>(Fleet in a Single Site)** | • 단일 가용성 존(Single AZ) 또는 단일 리전 환경 설계<br>• 단일 관리 도메인(Management Domain) 인스턴스가 프레임워크를 통해 복수의 독립 워크로드 도메인(Workload Domain) 인스턴스를 동시 통제 | • 모든 VCF Fleet 아키텍처의 표준 모델이자 다중 인스턴스 확장성 인프라의 토대 마련<br>• 단일 지역 내에서 다중 인스턴스를 동일한 운영 정책, 이미지 템플릿, 패치 주기로 일관되게 관리 가능 | • 전체 인프라가 1개의 물리 가용성 존에 상주하므로 데이터 센터 전력 마비, 전면 침수 등의 대규모 사이트 재해(Site Disaster)에 대처 불가<br>• 인스턴스 확장 시 Fleet 구성 요소와 관리 노드 간 네트워크 지연 시간(Latency) 및 대역폭 제약을 선행 검증해야 함 |
| **3. 다중 사이트 단일 리전 모델<br>(Fleet with Multiple Sites in a Single Region)** | • 단일 리전(Single Region) 내에서 물리적으로 격리된 두 개의 가용성 존(Dual AZ)에 걸쳐 단일 Fleet 인스턴스를 분산 배치<br>• 물리 하드웨어 그룹 단위로 자원을 완전히 격리하는 결함 도메인(Fault Domains) 기술 적용 | • 한쪽 가용성 존의 전력 중단, 네트워크 백본 단절, 냉각 장애 등 사이트 수준의 재해로부터 비즈니스 워크로드를 무중단 보호<br>• 장애 발생 시에도 무중단 가동으로 비즈니스 연속성(Business Continuity) 완벽 보장 | • 두 가용성 존 간의 실시간 데이터 동기화와 네트워크 망 단절 시의 뇌 분리(Split-brain) 현상을 통제하기 위한 고대역폭/초저지연 백본망 설계가 강제됨<br>• 가용성은 매우 높으나 지리적 리전(Region) 전체가 중단되는 대형 기후 재해 등에는 대응 불가 |
| **4. 다중 리전 다중 사이트 모델<br>(Fleet with Multiple Sites Across Multiple Regions)** | • 지리적으로 완전히 격리된 복수의 글로벌 리전(Multi-Region: 예: AMER, EMEA, APAC 등) 또는 글로벌 다중 사이트에 분산 배포<br>• 리전별 독립된 관리 평면을 연합(Federated)하여 통제 | • 글로벌 규모의 지리적 분산 수용 및 무제한에 가까운 프라이빗 클라우드 확장 체계 확보<br>• 전 세계 VCF 인프라의 글로벌 성능, 미사용 용량, 라이선스 준수 현황을 중앙에서 일괄 감시(Fleet-wide Governance) | • 대륙 간/리전 간 물리적 거리에 따른 네트워크 대기 시간(Latency) 패킷 손실률 매트릭스를 철저히 분석해야 함<br>• 규모가 극도로 증가하므로 관리 효율을 위해 리전별로 Fleet 경계를 분할하는 디자인 전략(예: One Fleet per Region)이 요구될 수 있음 |

---

### 💡 VCF Fleet 모델의 5가지 핵심 공통 아키텍처 기능
위 4가지 배포 모델은 하드웨어 규모와 가용성 존(AZ) 구조에 따라 분화되지만, 상위 개념 문서(`vmware-cloud-foundation-concepts.html`)에서 규정하는 **다음 5가지 중앙 집중형 핵심 프레임워크**를 공통적으로 구현하고 제공합니다.

1. **중앙 집중식 관리 평면 (Centralized Management Plane)**
   • 호스트가 지리적으로 어디에 배포되어 있든 관계없이 단일 콘솔 제어점에서 다중 VCF 인스턴스를 원격 통제합니다.
2. **통합 운영 프레임워크 (Unified Operations Framework)**
   • 개별 인스턴스마다 파편화된 운영 방식을 폐지하고, 전사 프라이빗 클라우드 전체에 일관된 보안 거버넌스와 운영 실무 정책을 동시 적용합니다.
3. **표준화된 라이프사이클 관리 (Standardized Lifecycle Management)**
   • Fleet 전반의 구성 요소들(ESXi, vCenter, NSX, vSAN 등)에 대해 조율되고 검증된 원클릭 자동 배포, 업그레이드, 유지보수 절차를 수행합니다.
4. **통합 모니터링 및 분석 (Integrated Monitoring and Analytics)**
   • 분산된 전체 VCF 인스턴스의 하드웨어 성능, 스토리지 남은 용량, 인프라 건전성 상태를 마스터 대시보드로 실시간 롤업(Roll-up)하여 시각화합니다.
5. **일관된 자동화 기능 (Consistent Automation Capabilities)**
   • 수천 대 규모의 서버 인프라 전체 차량에 걸쳐 완벽히 표준화된 IaC(Infrastructure as Code) 자동화 템플릿과 워크플로우를 대칭 배포하여 휴먼 에러를 차단합니다.

---

## 2. VCF Operations 모델 (VCF Operations Models)
인프라 전체의 실시간 모니터링, 성능 제어, 로그 분석, 비용 및 용량 관리를 담당하는 Operations 컴포넌트의 토폴로지 모델입니다.

| 배포 모델 (Deployment Model) | 속성 (Attributes) | 특장점 (Benefits) | 고려사항 및 제약 (Implications) |
| :--- | :--- | :--- | :--- |
| **단순형 운영 모델<br>(Simple Model)** | • 단일 노드(Single Node) 배포<br>• 추가 어플라이언스: 라이선스 서버, 클라우드 프록시, SDDC Manager 배포<br>• 스케일 업(Scale-up) 및 스케일 아웃(Scale-out) 아키텍처 모두 지원 | • 전체 모델 중 가장 작은 물리적/논리적 자원 설치 공간(Smallest footprint) 차지<br>• 자원 증설 필요 시 노드를 추가하여 고가용성(HA) 구조로 즉시 스케일 아웃 확장 가능 | • 하드웨어 장애 시 전체 서비스 복구 속도가 느림<br>• 호스트 장애 시 가상 머신 노드 재시작을 위해 플랫폼의 `vSphere HA` 기능에 전적으로 의존<br>• 호스트 장애 및 재부팅이 일어나는 다운타임 동안 모니터링, 경고, 차량 관리(Fleet) 서비스에 일시적 작동 중단(Interruption) 발생 |
| **고가용성형 운영 모델<br>(High Availability Model)** | • 3개 노드 고가용성 클러스터 구성:<br>  – 기본 노드 (Primary)<br>  – 복제 노드 (Replica)<br>  – 데이터 노드 (Data)<br>• 추가 어플라이언스: 라이선스 서버, 클라우드 프록시, SDDC Manager 배포<br>• 옵션 사항으로 외부 로드 밸런서(External LB) 연동 지원<br>• 개별 노드 스케일 업 및 추가 데이터 노드 증설을 통한 스케일 아웃 지원 | • 데이터 및 관리 상태 중복성(Data redundancy) 내장<br>• 클러스터 내부에서 단일 노드 장애가 발생하더라도 서비스가 유지되며 신속한 자동 복구(Rapid recovery) 지원 | • 기본 제공되는 복제 클라우드 프록시 노드를 수동으로 수집기 그룹(Collector group)으로 확장 구성 필요<br>• **외부 로드 밸런서 연동 시:**<br>  – 추가 네트워크 IP 주소 및 FQDN 요구<br>  – 모든 개별 노드 FQDN과 로드 밸런서 가상 FQDN이 SSL 인증서 주체 대체 이름(SAN) 항목에 필수 포함되어야 함 |
| **지속가용성형 운영 모델<br>(Continuous Availability Model)** | • 2개의 가용성 존(AZ)에 걸쳐 노드 쌍(Pair)으로 액티브 클러스터 분산 배치:<br>  – 주 존(Primary AZ): 기본 노드 + 데이터 노드<br>  – 보조 존(Secondary AZ): 기본 복제 노드 + 데이터 노드<br>• 주 존(Primary AZ) 전용: 라이선스 서버<br>• 양측 존(Both AZs) 대칭 배치: 클라우드 프록시, SDDC Manager | • 지리적/물리적으로 격리된 다른 가용성 존(AZ) 간 완벽한 동기 데이터 중복성 구현<br>• 메인 데이터 센터 한 곳(단일 가용성 존 전체)이 마비되는 물리적 재해 발생 시에도 운영 제어 및 모니터링 서비스 중단 없음(No service interruption) | • 초기 패키지 설치 완료 후 운영 모드 정상화를 위해 엔지니어의 일부 수동 작업(Manual operations) 수반<br>• 뇌 분리(Split-brain) 방지용 Witness 노드 배치를 위해 격리된 **제3의 가용성 존(Third AZ)** 공간 확보 필수<br>• 향후 신규 복구 관리 기점으로 활용할 수 있도록 보조 가용성 존 내부에 완전히 독립된 별도 VCF 인스턴스 구성을 강력 권장 |

---

## 3. VCF 자동화 모델 (VCF Automation Models)
엔드 유저 및 관리자에게 카탈로그 기반 인프라 셀프 서비스 및 DevOps 지향형 파이프라인 프로비저닝을 제공하는 자동화 컴포넌트의 구성 모델입니다.

| 세부 모델 (Model Options) | 특장점 (Benefits) | 고려사항 및 제약 (Implications) |
| :--- | :--- | :--- |
| **소형 배포 모델<br>(Small / Non-HA Deployment)** | • 최소한의 컴퓨팅 및 스토리지 풋프린트만 사용하여 개념 검증(PoC) 환경, 개발 샌드박스 또는 극소규모 인프라에 적합 | • 관리 노드 고가용성(HA)이 제공되지 않으므로, 해당 단일 가상 머신 장애 시 카탈로그 프로비저닝 등의 자동화 서비스 다운타임 발생 |
| **클러스터형 고가용성 모델<br>(Medium/Large HA Cluster)** | • 다중 가상 머신 기반 능동형 복제 클러스터를 설계하여 하드웨어 장애 시에도 24/7 중단 없는 무중단 인프라 셀프 서비스 보장 | • 로드 밸런서 인프라 구성, 가상 IP 풀 확보 등 초기 네트워킹 전제 조건과 다수의 관리 가상 머신 자원 오버헤드 존재 |

---

## 4. 워크로드 도메인 모델 (Workload Domain Models)
SDDC 자원을 논리적·물리적 특성에 맞게 경계 지어 인프라 수명 주기(Lifecycle) 및 자원 제어 권한을 할당하는 핵심 도메인 아키텍처입니다.

| 도메인 모델 (Model) | 주요 속성 (Attributes) | 특장점 (Benefits) | 고려사항 및 제약 (Implications) |
| :--- | :--- | :--- | :--- |
| **관리 도메인 모델<br>(Management Domain Model)** | • VCF 인스턴스 배포 시 최초로 생성되는 도메인<br>• vCenter, NSX Manager, SDDC Manager 등의 핵심 관리 컴포넌트 포함<br>• Fleet 관리 인프라 제공 | • 관리 전용 물리 컴퓨트, 네트워크, 스토리지 리소스를 워크로드와 완벽히 분리<br>• 관리 컴포넌트의 전용 하드웨어 규격 최적화 가능<br>• 관리 인프라의 전용 수명 주기 관리(LCM) 가능 | • 향후 추가 워크로드 도메인 증가 및 관리 컴포넌트 확장 시 관리 도메인의 리소스 증설이 필요할 수 있음 |
| **워크로드 도메인 모델<br>(Workload Domain Model)** | • 비즈니스 애플리케이션 및 사용자 워크로드를 실행하는 전용 리소스<br>• 전용 vCenter 및 vCenter Single Sign-On 도메인 소유 | • 독립적인 수명 주기 관리 지원<br>• 다른 VCF 도메인과 NSX 인스턴스 및 NSX Edge 클러스터 공유 가능<br>• 단일 VCF 인스턴스 당 최대 40개 워크로드 도메인까지 확장 가능 | • 비즈니스 워크로드를 격리하여 구동하기 위한 추가 하드웨어(ESXi 호스트) 자원 요구 |

| 세부 모델 (Model Options) | 특장점 (Benefits) | 고려사항 및 제약 (Implications) |
| :--- | :--- | :--- |
| **통합 도메인 모델<br>(Consolidated Domain)** | • 관리 평면(vCenter, SDDC Manager 등)과 실제 비즈니스 가상 머신 워크로드를 단일 가용성 클러스터 내에 통합하여 최소 물리 호스트 비용으로 시동 가능 | • 대규모 사용자 워크로드 폭증 시 동일 클러스터 내에 상주하는 핵심 관리 컴포넌트의 자원 경합 및 성능 저하 유발 가능성 존재 |
| **전용 워크로드 도메인 모델<br>(Dedicated Workload Domain)** | • 업무별 전용 vCenter 인스턴스와 격리된 컴퓨팅 리소스를 보장하여 완벽한 성능/보안 격리 제공 및 도메인 단위 독자적 롤링 업그레이드 지원 | • 도메인을 새롭게 분리 신설할 때마다 VCF가 요구하는 초기 클러스터 최소 호스트 규격(최소 3~4대 이상)을 만족해야 하므로 하드웨어 비용 증가 |

---

## 5. vSphere 클러스터 모델 (vSphere Cluster Models)
물리 하드웨어의 배치 레이아웃, 장애 복구 요구 규격 및 데이터 센터 내부 가용성에 따른 호스트 묶음 아키텍처 모델입니다.

| 클러스터 모델 (Model) | 특장점 (Benefits) | 고려사항 및 제약 (Implications) |
| :--- | :--- | :--- |
| **단일 랙 클러스터 모델<br>(Single-Rack vSphere Cluster)** | • 구성 및 인프라 구조가 매우 단순함<br>• 랙 로컬(Rack-local) 네트워크 환경에서 통신 효율 최적화 | • 전체 랙 장애(전원, 상단 스위치 등) 발생 시 클러스터 전체 서비스 중단 위험 존재 (물리적 단일 장애점) |
| **멀티 랙 Layer 2 클러스터 모델<br>(Multi-Rack L2 vSphere Cluster)** | • 여러 랙에 호스트를 분산하여 랙 레벨 가용성(Fault Tolerance) 확보<br>• 네트워크가 단일 L2 도메인으로 연장되어 복잡한 라우팅 불필요 | • 랙 간 가용성을 위해 Top-of-Rack(ToR) 스위치 간 L2 VLAN 확장 및 대역폭 보장이 필수적임 |
| **멀티 랙 Layer 3 클러스터 모델<br>(Multi-Rack L3 vSphere Cluster)** | • 랙 간 통신을 Layer 3 라우팅 기반으로 분리하여 네트워크 확장성 극대화<br>• L2 브로드캐스트 도메인을 격리하여 네트워크 안정성 확보 | • vMotion 및 호스트 TEP(Tunnel Endpoint) 통신을 위해 랙 간 L3 라우팅 인프라가 완벽히 구성되어야 함 |
| **스트레칭된 클러스터 모델<br>(Stretched vSphere Cluster)** | • 두 개 이상의 가용성 존(Availability Zones, AZ) 간에 클러스터를 결합하여 사이트 레벨 가용성 제공<br>• 주 사이트 재해 발생 시 타 사이트 자동 복구(HA) 제공 | • 두 사이트 간 극도로 낮은 네트워크 지연 시간(Round Trip Time) 및 높은 대역폭 요건 충족 필요<br>• 별도의 vSAN Witness 호스트 배포가 강제됨 |

---

## 6. 분산 스위치 모델 (Distributed Switch Models)
가상화 호스트들의 물리 NIC 포트를 논리적으로 추상화하여 트래픽 유형별 데이터 흐름을 제어하는 vSphere Distributed Switch(VDS) 모델입니다.

| 세부 모델 (Model Options) | 특장점 (Benefits) | 고려사항 및 제약 (Implications) |
| :--- | :--- | :--- |
| **단일 VDS 모델<br>(Single VDS)** | • 관리, vMotion, vSAN, NSX 오버레이 테넌트 트래픽을 단 하나의 가상 스위치 인프라에서 한눈에 통합 제어하므로 구성 및 모니터링이 극도로 직관적임 | • 이종 트래픽들이 동일 물리 업링크 포트를 공유하므로, 특정 트래픽 독점을 방지하기 위한 정교한 NIOC(네트워크 I/O 제어) 공유 정책 강제 |
| **다중 VDS 모델<br>(Multiple VDS)** | • 인프라 관리 전용망용 가상 스위치와 테넌트 업무용 가상 스위치를 물리/논리적으로 완벽 분리하여 강력한 보안 컴플라이언스 획득 | • 서버 호스트당 장착해야 하는 물리 NIC 포트 수와 이에 매핑되는 데이터 센터 탑 스위치의 물리 포트 케이블링 소모량이 배수로 증가 |

---

## 7. VCF Edge 모델 (VCF Edge Models)
VCF 가상화 환경 내부의 NSX 오버레이 가상 네트워크와 상단의 기업 물리 레거시 네트워크 망 사이를 연계해 주는 전용 Edge 가상 인프라 배치 모델입니다.

| 세부 모델 (Model Options) | 특장점 (Benefits) | 고려사항 및 제약 (Implications) |
| :--- | :--- | :--- |
| **중앙 집중식 Edge 모델<br>(Centralized Edge)** | • 관리 도메인 또는 특정 공유 서비스 인프라 클러스터 내에 모든 Edge 노드를 집중 배포하여 외부 라우팅 설정 변경 및 물리 BGP 연동 관리가 단순함 | • 모든 워크로드 도메인의 외부 진출입 트래픽이 특정 클러스터로 집중되므로, 트래픽 과부하 시 대형 네트워크 병목 현상 유발 위험 |
| **분산/전용 Edge 모델<br>(Dedicated Edge)** | • 워크로드 도메인 단위별로 독립적인 전용 Edge 클러스터를 전개하여 타 업무 세그먼트의 네트워크 간섭을 원천 차단하고 도메인별 최대 처리 대역폭 보장 | • 워크로드 도메인을 개설할 때마다 Edge 가상 머신 구동용 컴퓨트 및 스토리지 자원이 추가로 고정 할당되어 리소스 효율성 감소 |

---

## 8. 스토리지 모델 (Storage Models)
VCF 클라우드 인프라 아키텍처 내부에서 워크로드 데이터의 가용성, 복구 능력 및 입출력(I/O) 처리를 설계하는 데이터 스토리지 모델입니다.

| 세부 모델 (Model Options) | 특장점 (Benefits) | 고려사항 및 제약 (Implications) |
| :--- | :--- | :--- |
| **vSAN ESA<br>(Express Storage Architecture)** | • NVMe 하드웨어 아키텍처에 완전 최적화된 고성능 싱글 티어 구조로, 무손실 압축 기술과 압도적인 IOPS 성능 및 레이턴시 최소화 실현 | • 오직 고성능 NVMe 솔리드 스테이트 드라이브 및 VCF 공식 HCL 인증 하드웨어만 장착이 허용되어 초기 부품 인프라 비용 상승 |
| **vSAN OSA<br>(Original Storage Architecture)** | • 전통적인 캐시 디바이스 계층과 용량 디바이스 계층 분리형 2레벨 아키텍처로, 기존 가성비 중심의 SAS/SATA 드라이브 자산 혼용이 가능해 경제적임 | • 데이터 압축 효율 및 입출력 병렬 처리 성능이 차세대 ESA 아키텍처 대비 구조적으로 낮음 |
| **외부 스토리지 공유 모델<br>(Fibre Channel / NFS / iSCSI)** | • 기업이 기존에 운용 중이던 검증된 외산 하이엔드 FC SAN 스토리지 장비나 대용량 NAS 인프라 자산을 VCF 환경에 원클릭 매핑 및 지속 소비 가능 | • SDDC Manager를 통한 자동 스토리지 프로비저닝 및 펌웨어 원클릭 수명 주기 관리(LCM) 통합 제어 범주에서 제외되어 수동 운영 요소 수반 |

---

## 9. 네트워크 패브릭 모델 (Network Fabric Models)
VCF 프라이빗 클라우드가 배포되는 물리 랙 환경과 상단 데이터 센터 스위치 장비 간의 물리 하드웨어 배선 및 라우팅 설계 모델입니다.

| 세부 모델 (Model Options) | 특장점 (Benefits) | 고려사항 및 제약 (Implications) |
| :--- | :--- | :--- |
| **Layer 2 패브릭 모델<br>(Layer 2 Fabric)** | • 동일한 L2 브로드캐스트 도메인을 물리 랙 간에 평면 연장하여, 호스트 간 이동(vMotion) 시 복잡한 가상 IP 재설정 없는 직관적 구성 가능 | • 데이터 센터 스케일이 거대해질 경우 브로드캐스트 트래픽 루핑 및 스톰 위험에 취약하며 네트워크 대규모 확장성의 한계 직면 |
| **Layer 3 패브릭 모델<br>(Layer 3 Fabric)** | • 현대적인 Leaf-Spine 물리 아키텍처 기반의 L3 라우팅 격리를 구현하여 브로드캐스트 도메인을 철저히 분리하고, 수천 대 호스트 단위로 무한 확장 가능 | • 호스트 하드웨어 간 가상 터널(TEP) 패킷 통신 처리를 위해 물리 네트워크 레벨에서의 고도화된 동적 라우팅 프로토콜(BGP 등) 설계 구성 역량 필수 |

---

## 10. NSX 관리 및 제어 평면 모델 (NSX Management and Control Plane Models)
네트워크 소프트웨어 정의화(SDN) 및 보안 방화벽 정책을 통합 제어하는 NSX Manager 엔진의 토폴로지 구성 모델입니다.

| 세부 모델 (Model Options) | 특장점 (Benefits) | 고려사항 및 제약 (Implications) |
| :--- | :--- | :--- |
| **통합 NSX Manager 모델<br>(Unified NSX Manager)** | • 단일 공유 NSX Manager 고가용성 클러스터가 전체 관리 도메인 및 다수의 워크로드 도메인 가상 네트워크를 일괄 제어하므로 인프라 자원 소모 최소화 | • 하나의 NSX 제어 평면 엔진에 장애 발생 또는 메이저 패치 수행 시 연동된 전체 도메인의 네트워크 신규 제어 권한 일시 마비 (Blast Radius 확장) |
| **전용 NSX Manager 모델<br>(Dedicated NSX Manager)** | • 엔터프라이즈 미션 크리티컬 워크로드 도메인 단위마다 독립된 별도의 NSX Manager 제어 클러스터를 단독 배정하여 완벽한 관리 격리와 무결성 확보 | • 도메인 개수 배수만큼 NSX 가상 머신 인프라가 추가 배포되므로 핵심 컴퓨팅 메모리 및 CPU 자원의 아키텍처 오버헤드 유발 |

---

## 11. 네트워킹 모델 (Networking Models)
VCF 테넌트 및 비즈니스 애플리케이션 가상 머신들이 통신을 수행하기 위해 아키텍처상에서 가상 스위치 세그먼트를 생성하는 모델입니다.

| 세부 모델 (Model Options) | 특장점 (Benefits) | 고려사항 및 제약 (Implications) |
| :--- | :--- | :--- |
| **오버레이 네트워킹 모델<br>(Overlay Networking)** | • 하드웨어 스위치 하부 구조의 변경 요건 없이, 소프트웨어 콘솔에서 GENEVE 캡슐화 가상 터널을 통해 즉시 가상 L2/L3 세그먼트 가상화 생성 및 멀티테넌시 완벽 지원 | • 가상 패킷 캡슐화 인코딩/디코딩 통신 처리를 위해 하부 물리 스위치 및 백본 인프라 전체 망의 점보 프레임(MTU 1700 이상 필수, 9000 권장) 환경 셋팅 의무화 |
| **VLAN 지원 네트워킹 모델<br>(VLAN-Backed Networking)** | • 전통적인 데이터 센터의 물리 VLAN ID 망 환경과 가상 머신 포트 그룹을 다이렉트로 일대일 가속 매핑하여 패킷 오버헤드가 없으며, 네트워크 가시성이 명확함 | • 새 가상 네트워크 세그먼트 추가 시마다 상부 물리 스위치 인프라 부서의 VLAN ID 할당 및 변경 승인이 상시 동반되며 최대 생성 개수(4094개) 장벽 존재 |

---

## 12. NSX Edge 클러스터 모델 (NSX Edge Cluster Models)
인프라 외부 진출입 게이트웨이(Tier-0 및 Tier-1) 역할을 담당하는 Edge 노드들 간의 가용성 작동 메커니즘 및 패킷 처리 방식을 정의하는 모델입니다.

| 세부 모델 (Model Options) | 특장점 (Benefits) | 고려사항 및 제약 (Implications) |
| :--- | :--- | :--- |
| **Active/Active 모델<br>(Active/Active Cluster)** | • ECMP(Equal-Cost Multi-Pathing) 동적 라우팅 경로를 활성화하여 클러스터 내 모든 Edge 노드가 상시 데이터 처리에 동시 참여하므로 North-South 처리 대역폭 극대화 | • 상시 데이터 경로 분산 처리 아키텍처 특성으로 인해 세션 상태 추적이 엄격히 요구되는 분산 상태 저장 방화벽, Stateful NAT 등의 고도화된 네트워킹 기능 구현 제약 |
| **Active/Standby 모델<br>(Active/Standby Cluster)** | • 주 가동(Active) 노드와 실시간 하트비트 세션 동기화를 유지하는 대기(Standby) 노드로 구성되어 장애 발생 시 1초 미만의 세션 유실 없는 무중단 장애 조치 보장 | • 전체 트래픽 처리 한계가 현재 활성화되어 구동 중인 단일 Edge 물리 노드의 성능 임계치 규격으로 제한되는 대역폭 바운더리 한계 존재 |

---

## 13. Fleet 관리 레벨 컴포넌트 네트워킹 모델 (Fleet Level Components Networking Models)
다중 VCF 인스턴스 또는 원격 사이트 환경이 결합되어 있을 때 최상위 Fleet 레벨의 다중 관리 컴포넌트 간 백본 연동 통신을 규정하는 모델입니다.

| 세부 모델 (Model Options) | 특장점 (Benefits) | 고려사항 및 제약 (Implications) |
| :--- | :--- | :--- |
| **글로벌 크로스 사이트 모델<br>(Global Cross-Site Fabric)** | • 지리적으로 멀리 떨어진 다중 원격 데이터 센터의 Fleet 자원 컴포넌트들이 단일 공유 네트워크 가상 패브릭 위에서 마치 한 공간처럼 투명하게 상호 통신 | • 원격 사이트 간 안정적이고 유실 없는 전용 광대역 사설망(WAN) 백본 인프라스트럭처 도입 및 상시 전용 라인 비용 유지를 전제 조건으로 삼음 |
| **독립형 사이트 링크 모델<br>(Isolated Site-Link)** | • 각 로컬 사이트 내부의 통신망은 철저하게 해당 물리 랙 영역 내부에서 안전하게 독립 완결되며, 상위 마스터로는 통계 및 거버넌스 메트릭 정보만 비동기 상신함 | • 여러 사이트를 넘나드는 실시간 라이브 마이그레이션(Dynamic Cross-vCenter vMotion) 아키텍처나 통합형 실시간 통합 제어 주기를 완벽히 동기화하는 데 제약 발생 |

---

## 14. VCF 단일 로그인 모델 (VCF Single Sign-On Models)
전사 프라이빗 클라우드 소프트웨어 정의 데이터 센터(SDDC)의 통합 사용자 ID 인증, 다중 테넌트 권한 체계 및 Single Sign-On 관리 경계를 설계하는 모델입니다.

| 세부 모델 (Model Options) | 특장점 (Benefits) | 고려사항 및 제약 (Implications) |
| :--- | :--- | :--- |
| **단일 공유 SSO 도메인<br>(Single Shared SSO)** | • 단 한 번의 통합 마스터 계정 로그인 행위만으로 전사 VCF 플랫폼 인스턴스, SDDC 관리 평면 및 모든 연동 vCenter 시스템까지 원클릭 교차 접근 제어 허용 | • 최상위 마스터 권한자 계정 탈취나 허브 단일 SSO 서비스 인프라 전반에 시스템 오류 발생 시 프라이빗 클라우드 전사 제어 통제권 마비의 취약점 상존 |
| **분리형/연합 SSO 도메인<br>(Isolated/Federated SSO)** | • 업무 목적, 보안 등급 또는 인스턴스 경계 단위별로 완전히 분리된 독자적 SSO 도메인 인증 체계를 수립하여 보안 폭파 반경(Blast Radius)을 철저히 차단 | • 시스템 엔지니어가 다수의 이종 워크로드 도메인 인프라를 교차 유지 보수하거나 상태 점검 시 도메인별 개별 인증 절차가 매번 요구되어 운영 피로도 가중 |

---

## 15. vSphere Supervisor 모델 (vSphere Supervisor Models)
VCF 프라이빗 클라우드 인프라 커널 레벨 내부에 쿠버네티스(Kubernetes) 제어 평면 엔진을 네이티브하게 임베딩하여 컨테이너 런타임을 제공하는 아키텍처 모델입니다.

| 세부 모델 (Model Options) | 특장점 (Benefits) | 고려사항 및 제약 (Implications) |
| :--- | :--- | :--- |
| **NSX 통합형 Supervisor<br>(NSX-Backed Supervisor)** | • K8s 포드(Pod) 또는 네임스페이스 생성 명령 발생 시 NSX가 즉시 연동되어 고성능 분산 방화벽 보안 룰 및 로드 밸런서 IP 자동화를 컨테이너 레벨까지 완벽 관제 | • 해당 워크로드 도메인 스택 내부에 가상 네트워킹을 위한 NSX Edge 클러스터 및 가상 스위칭 인프라 환경이 완벽히 사전 구축 및 검증 완료되어 있어야 함 |
| **VDS 가상 스위치형 Supervisor<br>(VDS-Backed Supervisor)** | • NSX 네트워크 가상화 인프라 도입 부담 없이 기존의 가상 스위치(VDS) 토폴로지 환경 위에서 바로 타사 외부 로드 밸런서(Avi 등)를 결합하여 심플한 쿠버네티스 런타임 구동 | • 컨테이너 포드 단위별 세밀한 마이크로 세그멘테이션 분산 보안 방화벽 정책 제어나 테넌트별 동적 가상 라우팅 격리 처리가 불가능하여 대형 대규모 멀티테넌트 환경엔 제약 |
