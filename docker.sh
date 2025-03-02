#!/bin/bash

# growpart /dev/nvme0n1 4
# lvextend -l +50%FREE /dev/RootVG/rootVol
# lvextend -l +50%FREE /dev/RootVG/varVol
# xfs_growfs /
# xfs_growfs /var

dnf -y install dnf-plugins-core
dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y
systemctl start docker
systemctl enable docker
usermod -aG docker ec2-user
newgrp docker