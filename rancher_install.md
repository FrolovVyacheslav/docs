# Installing Rancher on a single node (RKE cluster) using [Helm](https://helm.sh/docs/) chart in Hetzner provider
See the [Rancher requirements](https://rancher.com/docs/rke/latest/en/os/).

---

## Host prerequisites
* Install Docker via [rancher script](https://github.com/rancher/install-docker) run 
`curl https://releases.rancher.com/install-docker/20.10.sh | sh`
* Install ntp package `apt install ntp -y`. This prevents errors with certificate validation. 
* Following sysctl settings must be applied, check it running `sysctl -a | grep net.bridge.bridge-nf-call-iptables`
* `sed -i 's/[#]*AllowTcpForwarding yes/AllowTcpForwarding yes/g' /etc/ssh/sshd_config`

## Server Configuration

### Basic server security:
```
sed -i 's/[#]*PermitRootLogin yes/PermitRootLogin prohibit-password/g' /etc/ssh/sshd_config
sed -i 's/[#]*PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
apt install fail2ban -y
```

### SSH keys:
Create a pair of ssh keys to install RKE cluster on the host.

```
ssh-keygen -q -f ~/.ssh/rancher_server -t ed25519
cat ~/.ssh/rancher_server.pub >> ~/.ssh/authorized_keys
echo "IdentityFile ~/.ssh/rancher_server" > ~/.ssh/config
systemctl restart sshd.service
```

### Firewall settings
```
ufw allow proto tcp from any to any port 22,80,443
ufw allow from 10.43.0.0/16                             # service IP range
ufw allow from 10.42.0.0/16                             # pod IP range, as configured by RKE
ufw allow from 10.0.0.0/16                              # internal network range
ufw -f default deny incoming
ufw -f default allow outgoing
ufw enable
```

## RKE Kubernetes installation
Our choice of Rancher 2.5 as it has a more human-friendly interface than 2.6 version. See the 
[Suse matrix](https://www.suse.com/suse-rancher/support-matrix/all-supported-versions/rancher-v2-5-10/)
for recommended versions of RKE, Docker, and other stuff for Rancher Server versions.

See the [RKE releases and supported Kubernetes versions](https://github.com/rancher/rke/releases)

### Download the RKE binary:
```
wget -O rke https://github.com/rancher/rke/releases/download/v1.2.13/rke_linux-amd64
chmod u+x rke && mv rke /usr/local/bin/
rke config --list-version --all
```

### Creating the cluster configuration file
This file describe RKE cluster. See the example [cluster.yml](cluster.yml) file

### Deploy kubernetes cluster & grant control access
Run `rke up` in directory with [cluster.yml](cluster.yml) file created above.

> :warning: After deploying the cluster, two new files will be appear.
>`cluster.rkestate` and `kube_config_cluster.yml` is private files because they contain secrets!
- `cluster.rkestate` - the state of the cluster so that when you run `rke up` again later RKE knows the current state
- `kube_config_cluster.yml` - the kubeconfig file that you need to use to manage the cluster with kubectl

Run `mkdir ~/.kube/ && mv kube_config_cluster.yml ~/.kube/config && chmod -R 600 ~/.kube/`\
to further configure Rancher server.

## Install kubectl
```
curl -LO https://dl.k8s.io/release/v1.21.6/bin/linux/amd64/kubectl    # download binary kubectl
curl -LO "https://dl.k8s.io/v1.21.6/bin/linux/amd64/kubectl.sha256"   # download checksum file
echo "$(<kubectl.sha256) kubectl" | sha256sum --check                 # check
install -m 0755 kubectl /usr/local/bin/kubectl        # install kubectl
kubectl version --client
```

# Install helm
```
wget -O helm https://get.helm.sh/helm-v3.7.1-linux-amd64.tar.gz
tar -zxvf helm
mv linux-amd64/helm /usr/local/bin/
helm version
```

# Install cert-manager
`kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.6.0/cert-manager.yaml`

# Install Rancher
```
kubectl create namespace cattle-system
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
helm install rancher rancher-stable/rancher --namespace cattle-system --set hostname=<example.com> --set ingress.tls.source=letsEncrypt --set letsEncrypt.email=<valid_email> --version 2.5.10
```

>Access to a Rancher server and get certificate may take few minutes after installing Rancher

For deploy Kubernetes cluster using a node driver see [next steps](rancher_hetzner.md)