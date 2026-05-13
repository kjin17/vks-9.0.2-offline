VKS Offline Isntallation Preparation List

1. Harbor VM Template - bitnami harbor
   download > https://bitnami.com/stack/harbor/virtual-machine 
2. Avi Controller - 31.1.2-P21
   download > broadcom support portal
3. VCF-cli (vcf-cli_linux_amd64_9_0_2.tar.gz)
   download > https://packages.broadcom.com/artifactory/vcf-distro/vcf-cli/
   reference : https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-0/building-your-cloud-applications/getting-started-with-the-tools-for-building-applications/installing-and-using-vcf-cli-v9/installing-the-vcf-cli-in-internet-connected-environments/install-the-vcf-cli(3)/install-vcf-cli-plugins.html
4. vcf-cli plugin 
   download > vcf plugin download-bundle --to-tar /tmp/FILE-NAME.tar.gz
   change default source > vcf plugin source update default --uri registry.example.com/vcf_cli/plugins/plugin-inventory:latest
   reference : https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-9-0-and-later/9-0/building-your-cloud-applications/getting-started-with-the-tools-for-building-applications/installing-and-using-vcf-cli-v9/installing-the-vcf-cli-in-internet-restricted-environments(2).html
5. kubectl
   download > curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
6. VKR
   download > https://wp-content.vmware.com/v2/latest/
   VKS 3.5.0 기준 지원 버전
   - v1.31.4 / v1.31.7 / v1.31.11
   - v1.32.0 / v1.32.3 / v1.32.7
   - v1.33.1 / v1.33.3
   - v1.34.1 / v1.34.2
7. VKS Addon Pacakges
8. Supervisor Services
   - Packages file (from Broadcom support portal)
   - Data Values file (from Broadcom support portal)
   - Supervisor Services Images
     download > imgpkg copy -b projects.packages.broadcom.com/vsphere/supervisor/harbor-service/2.14.2_vmware.2-vks.1 --to-tar=./harbor_v2.14.2.tar (이미지 repo 는 각 Packages file 내 images: 항목 참고)
     - Harbor
     - Argocd
     - Contour
     - VKS
     - Management Proxy
9. carvel tool
   - imgpkg
   - kapp
   - kbld
   - kctrl
   - kwt
   - ytt
10. VKSm Extension
    download > download-extension.sh (/extensions/9.0.2-0-25145732/.../...:latest)
    reference : https://techdocs.broadcom.com/us/en/vmware-cis/vcf/vcf-consumption/latest/managing-vks-clusters-with-vks-cluster-management/installation-and-enablement-of-vks-cluster-management/enabling-vks-cluster-management-in-an-airgapped-environment-without-fds.html
11. multi zonal supervisor script (json) (Optional)
12. Helm (Optional)
13. Keycloak (Optional)
14. Docker
15. argocd CLI
16. Velero CLI



   
---

VKS Offline Installation

1. Bastion VM
   - install kubectl
    > install ./kubectl /usr/bin/kubectl
   - install vcf-cli
    > install ./kubectl /usr/bin/kubectl 
   - upload vcf cli plugin
      > docker login <harbor-fqdn> --tls-verify=false
      > vcf config cert add --host <harbor-fqdn> --ca-certificate harbor-ca.crt
      > vcf plugin upload-bundle --tar /tmp/FILE-NAME.tar.gz --to-repo registry.example.com/vcf_cli/plugins
      > vcf plugin source update default --uri <harbor-fqdn>/vcf_cli/plugins/plugin-inventory:latest
      > vcf plugin clean && vcf plugin list
   - install Argocd CLI
   - install velero cli
2. Harbor VM
   - deploy Harbor VM from Bitnami VM Template (bitnami-harbor-2.14.2-r0-debian-12-amd64.ova)
   - 최초 부팅 전 disk 구성 정보 수정 필요 Disk 1 - 100GB + Disk 2 - 100GB
   - harbor-registry mount
     > sudo fdisk /dev/sdb
       sudo mkfs.ext4 /dev/sdb1
       sudo mount /dev/sdb1 /bitnami/harbor-registry/storage
       chown harbor storage
   - 인증서 생성
     # root CA 
     openssl genrsa -out admin-ca.key 4096
     openssl req -x509 -new -nodes -sha512 -days 3650 -subj "/C=US/ST=CA/L=PaloAlto/O=VCF/OU=Supervisor/CN=Harbor" -key admin-ca.key -out admin-ca.crt

     # Harbor Cert
     openssl genrsa -out harbor.key 4096
     openssl req -sha512 -new -subj "/C=US/ST=CA/L=PaloAlto/O=VCF/OU=Supervisor/CN=mgd-harbor.psolab.local" -key harbor.key -out harbor.csr

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

     openssl x509 -req -sha512 -days365 -extfile v3.ext -CA admin-ca.crt -CAkey admin-ca.key -CAcreateserial -in harbor.csr -out harbor.crt

     # Validate
     harbor.crt / harbor.key / harbor.csr / admin-ca.crt / admin-ca.key

     # enable SSH
     sudo sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
     sudo rm -rf /etc/ssh/sshd_not_to_be_run
     sudo systemctl enable sshd
     sudo systemctl restart sshd

     # Replace Certificate
     cat ./harbor.key > /opt/bitnami/nginx/conf/bitnami/certs/server.key
     cat ./harbor.crt > /opt/bitnami/nginx/conf/bitnami/certs/server.crt

     # Restart Harbor
     sudo /opt/bitnami/ctlscript.sh restart bitnami.nginx/conf/bitnami/certs/server
        
