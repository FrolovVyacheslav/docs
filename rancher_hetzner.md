# Creating Kubernetes cluster

## Installing the node driver
Head to the "Global" in Rancher WEB UI and click on "Tools" > "Drivers" > "Node Drivers" > "Add Node Driver" and fill in 
the appropriate fields.

- Download URL:
`https://github.com/JonasProgrammer/docker-machine-driver-hetzner/releases/download/3.5.0/docker-machine-driver-hetzner_3.5.0_linux_amd64.tar.gz`

- Custom UI URL:
`https://storage.googleapis.com/hcloud-rancher-v2-ui-driver/component.js`

- Whitelist Domains:
`storage.googleapis.com`

## Creating the node templates (control and workers)

Click to the "Node Template" > "Add Template", select "Hetzner" provider and enter your Hetzner API token.
Enter the fields:
- Region
- Image: Ubuntu 20.04
- Size (type of server)
- Name of template
- [Cloud-init Configuration](https://cloudinit.readthedocs.io/en/latest/topics/examples.html):
```
packages:
  - fail2ban
package_update: true
package_upgrade: true
runcmd:
  - sed -i 's/[#]*PermitRootLogin yes/PermitRootLogin prohibit-password/g' /etc/ssh/sshd_config
  - sed -i 's/[#]*PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
ssh_authorized_keys:
  - <admin_ssh_public_key>
  - <rancher_ssh_public_key>
```

Select the "Private network" in "Networks".
> Sometimes it's looks like a bug: nodes can't connect to private network during deployment cluster.
Try to click on network name before "Create" a template.

Click "Create" and click on three dots opposite the template name and press "Clone". Fill in the appropriate fields for
worker template.

## Creating the cluster
Head to the "Global" > "Clusters" and click on "Add Cluster", select "Hetzner" as the provider,
in "Kubernetes Options" > "Network Provider" set "Flannel", "Cloud Providers" set "External"

Then click on "Edit As YAML" and make changes: See [cluster_conf.yml](cluster_conf.yml)

Click on "Create".
