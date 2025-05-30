#!/bin/bash
ARCH=amd64
PLATFORM=$(uname -s)_$ARCH

# Redirect all output to a log file
exec > /var/log/user-data.log 2>&1

echo "###### extending volumes properly ######"
growpart /dev/nvme0n1 4
lvextend -l +50%FREE /dev/RootVG/rootVol
lvextend -l +50%FREE /dev/RootVG/varVol
xfs_growfs /
xfs_growfs /var
echo "###### extending volumes successful ######"

echo "###### Installing docker ######"
dnf -y install dnf-plugins-core
dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user
newgrp docker
echo "###### docker installation successful ######"

echo "###### Installing kubectl and eksctl ######"
#kubectl installation
curl -O https://s3.us-west-2.amazonaws.com/amazon-eks/1.32.0/2024-12-20/bin/linux/amd64/kubectl
chmod +x ./kubectl
mv kubectl /usr/local/bin/kubectl

#eksctl
curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"
tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp && rm eksctl_$PLATFORM.tar.gz
mv /tmp/eksctl /usr/local/bin
echo "###### kubectl and eksctl installed ######"

# To avoid mentioning the namespace name (-n namespacename) in  kubectl commands 
# install the tool kubens

sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx
sudo ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx
sudo ln -s /opt/kubectx/kubens /usr/local/bin/kubens
echo "###### kubens installed ######"

# kubens <namespace_name>  -- set the name of namespace
# kubens expense

# ebs csi driver for EBS(Elastic Block Storage)
kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.40"
echo "###### EBS csi driver installed ######"

kubectl apply -k "github.com/kubernetes-sigs/aws-efs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-2.1"
echo "###### EFS csi driver installed ######"

# k9s installation
curl -sS https://webinstall.dev/k9s | bash
echo "###### k9s installed ######"

curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
echo "###### HELM Installed ######"

# Before resizing
# [ ec2-user@ip-172-31-37-83 ~ ]$ lsblk
# NAME                 MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
# nvme0n1              259:0    0   50G  0 disk
# ├─nvme0n1p1          259:1    0    1M  0 part
# ├─nvme0n1p2          259:2    0  122M  0 part /boot/efi
# ├─nvme0n1p3          259:3    0  488M  0 part /boot
# └─nvme0n1p4          259:4    0 19.4G  0 part
#   ├─RootVG-rootVol   253:0    0    6G  0 lvm  /
#   ├─RootVG-swapVol   253:1    0    2G  0 lvm  [SWAP]
#   ├─RootVG-homeVol   253:2    0    1G  0 lvm  /home
#   ├─RootVG-varVol    253:3    0    2G  0 lvm  /var
#   ├─RootVG-varTmpVol 253:4    0    2G  0 lvm  /var/tmp
#   ├─RootVG-logVol    253:5    0    2G  0 lvm  /var/log
#   └─RootVG-auditVol  253:6    0  4.4G  0 lvm  /var/log/audit


# [ ec2-user@ip-172-31-37-83 ~ ]$ df -h
# Filesystem                    Size  Used Avail Use% Mounted on
# devtmpfs                      4.0M     0  4.0M   0% /dev
# tmpfs                         355M     0  355M   0% /dev/shm
# tmpfs                         142M  2.4M  140M   2% /run
# /dev/mapper/RootVG-rootVol    6.0G  2.2G  3.8G  37% /
# /dev/mapper/RootVG-homeVol    960M   40M  921M   5% /home
# /dev/mapper/RootVG-varVol     2.0G  387M  1.6G  20% /var
# /dev/mapper/RootVG-logVol     2.0G   66M  1.9G   4% /var/log
# /dev/mapper/RootVG-auditVol   4.4G   64M  4.3G   2% /var/log/audit
# /dev/mapper/RootVG-varTmpVol  2.0G   47M  1.9G   3% /var/tmp
# /dev/nvme0n1p3                424M  223M  202M  53% /boot
# /dev/nvme0n1p2                122M  7.0M  115M   6% /boot/efi
# tmpfs                          71M     0   71M   0% /run/user/1001

#--------------------
# After resizing

# [ ec2-user@ip-172-31-43-15 ~ ]$ lsblk
# NAME                 MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
# nvme0n1              259:0    0   50G  0 disk
# ├─nvme0n1p1          259:1    0    1M  0 part
# ├─nvme0n1p2          259:2    0  122M  0 part /boot/efi
# ├─nvme0n1p3          259:3    0  488M  0 part /boot
# └─nvme0n1p4          259:4    0 49.4G  0 part
#   ├─RootVG-rootVol   253:0    0   21G  0 lvm  /
#   ├─RootVG-swapVol   253:1    0    2G  0 lvm  [SWAP]
#   ├─RootVG-homeVol   253:2    0    1G  0 lvm  /home
#   ├─RootVG-varVol    253:3    0  9.5G  0 lvm  /var
#   ├─RootVG-varTmpVol 253:4    0    2G  0 lvm  /var/tmp
#   ├─RootVG-logVol    253:5    0    2G  0 lvm  /var/log
#   └─RootVG-auditVol  253:6    0  4.4G  0 lvm  /var/log/audit

# 52.54.180.31 | 172.31.43.15 | t3.micro | null
# [ ec2-user@ip-172-31-43-15 ~ ]$ df -hT
# Filesystem                   Type      Size  Used Avail Use% Mounted on
# devtmpfs                     devtmpfs  4.0M     0  4.0M   0% /dev
# tmpfs                        tmpfs     355M     0  355M   0% /dev/shm
# tmpfs                        tmpfs     142M  2.4M  140M   2% /run
# /dev/mapper/RootVG-rootVol   xfs        21G  1.9G   20G   9% /
# /dev/mapper/RootVG-homeVol   xfs       960M   40M  921M   5% /home
# /dev/mapper/RootVG-varVol    xfs       9.5G  329M  9.2G   4% /var
# /dev/nvme0n1p3               xfs       424M  223M  202M  53% /boot
# /dev/nvme0n1p2               vfat      122M  7.0M  115M   6% /boot/efi
# /dev/mapper/RootVG-logVol    xfs       2.0G   66M  1.9G   4% /var/log
# /dev/mapper/RootVG-varTmpVol xfs       2.0G   47M  1.9G   3% /var/tmp
# /dev/mapper/RootVG-auditVol  xfs       4.4G   64M  4.3G   2% /var/log/audit
# tmpfs                        tmpfs      71M     0   71M   0% /run/user/1001

# check the docker.sh file has windows supported endings

# cat -A docker.sh

# use the below command to convert
# dos2unix docker.sh

# Other option is select LF in visual studio code

# To check userdata output
# sudo tail -f /var/log/cloud-init-output.log
# sudo cat /var/log/user-data.log