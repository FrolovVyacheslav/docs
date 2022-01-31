#!/bin/bash
curl https://releases.rancher.com/install-docker/20.10.sh | sh
apt-mark hold docker*
sed -i 's/[#]*AllowTcpForwarding yes/AllowTcpForwarding yes/g' /etc/ssh/sshd_config
apt install fail2ban -y
ssh-keygen -q -f ~/.ssh/rancher_server -t ed25519 -N ""
cat ~/.ssh/rancher_server.pub >> ~/.ssh/authorized_keys
echo "IdentityFile ~/.ssh/rancher_server" > ~/.ssh/config
systemctl restart sshd.service
ufw allow proto tcp from any to any port 22,80,443
ufw allow from 10.43.0.0/16
ufw allow from 10.42.0.0/16
ufw allow from 10.0.0.0/16
ufw -f default deny incoming
ufw -f default allow outgoing
ufw enable
timedatectl set-timezone Europe/Moscow
wget -O rke https://github.com/rancher/rke/releases/download/v1.2.13/rke_linux-amd64
chmod u+x rke && mv rke /usr/local/bin/
curl -LO https://dl.k8s.io/release/v1.21.6/bin/linux/amd64/kubectl
install -m 0755 kubectl /usr/local/bin/kubectl
wget -O helm https://get.helm.sh/helm-v3.7.1-linux-amd64.tar.gz
tar -zxvf helm && mv linux-amd64/helm /usr/local/bin/
echo ""
echo "Now you can create cluster.yml, run 'rke up', install cert-manager and Rancher UI"
