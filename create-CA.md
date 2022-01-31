## Install [cert-manager](https://cert-manager.io/) in new cluster
Go to Rancher, choose a created cluster and click "Kubeconfig File". This file will allow you 
to manage the cluster from any machine via kubectl. Copy the content to `~/.kube/config` and run `chmod -R 600 ~/.kube`  

> :ok_hand: To bash auto-completion on Linux run:\
>source <(kubectl completion bash)\
>echo "source <(kubectl completion bash)" >> ~/.bashrc 


List of [cert-manager actual versions](https://cert-manager.io/docs/installation/supported-releases/)

The default static cert-manager configuration can be installed as follows:
`kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.6.0/cert-manager.yaml`

## Create workload ingress
Create an A-record endpoint with the load balancer ip and add worker nodes of the cluster to LB targets with TCP 
services on 80 and 443 ports. In Rancher, create a workload for which the certificate will be issued.

### nginx_ingress.yml:
Run the ingress using the file described below `kubectl apply -f nginx-ingress.yml`

```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress                     # Ingress name
  namespace: default                    # Namespace where are workload placed
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: app.com                       # Domain name of endpoint created with an A-record
    http:
      paths:
        - pathType: Prefix
          path: /
          backend:
            service: 
              name: app                # Name of service workload
              port:
                number: 80
```

> Note: Check ingress in Rancher UI or run `kubectl get ingress -n default`. If it has started successfully and 
> application worked you can use the domain name via http&#58;//app.com.

## Create issuer
`Issuers` and `ClusterIssuers`, are Kubernetes resources that represent certificate authorities that are able to 
generate signed certificates by honoring certificate signing requests.
- Kind: `Issuer` means that you intend to get a certificate for one namespace.
- Kind: `ClusterIssuer` means that you intend to get a cross namespaces certificate

When you create a new ACME issuer with solver "http01" cert-manager will generate a private key which is used to 
identify you with the ACME server.

[More info about issuers](https://cert-manager.io/docs/concepts/issuer/) 

> :warning: To reduce the chance of you hitting Let's Encrypt limits it is highly recommended starting by using the 
> staging environment.

Below you will see examples of using staging and production issuers. 
> Note: Use only valid email

### issuer_staging.yml:
```
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: letsencrypt-staging                                        # issuer name
  namespace: default                                               # the namespace for which the certificate is issued
spec:
  acme:
    email: <valid e-mail address>
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-staging-private-key
    solvers:
    - http01:
        ingress:
          class: nginx
```

### issuer_prod.yml:
```
apiVersion: cert-manager.io/v1
kind: ClusterIssuer                                        # Example of a Cluster Issuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    email: <valid e-mail address>
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod-private-key
    solvers:
    - http01:
        ingress:
          class: nginx
```

Run `kubectl apply -f issuer_staging.yml`

To make sure the issuer was successfully created run:
`kubectl get issuers.cert-manager.io -n default` or\
`kubectl get clusterissuers.cert-manager.io`

If Issuer state is "True" modify `nginx_ingress.yml file to get staging certificate:

### new_nginx_ingress.yml
```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  namespace: default
  annotations:
    kubernetes.io/ingress.class: nginx    
    cert-manager.io/cluster-issuer: "letsencrypt-staging"
spec:
  tls:
  - hosts:
    - app.com
    secretName: app-tls
  rules:
  - host: app.com
    http:
      paths:
        - pathType: Prefix
          path: /
          backend:
            service: 
              name: app
              port:
                number: 80
```

In new ingress file you modify "annotations" and "spec" fields to specify issuer and which domain you want to 
request a certificate. After it run `kubectl apply -f new_nginx_ingress.yml` to request certificate. If all field and 
issuer are correct you can check all steps in chain\
[Certificate](https://cert-manager.io/docs/concepts/certificate/) -> 
[CertificateRequest](https://cert-manager.io/docs/concepts/certificaterequest/) -> 
[Orders](https://cert-manager.io/docs/concepts/acme-orders-challenges/) -> 
[Challenges](https://cert-manager.io/docs/concepts/acme-orders-challenges/) :

`kubectl get certificate -n default`\
State "True" is ok. "SECRET" contain certificate and private key.
For more info run:\
`kubectl describe certificate -n default`

In next step generated "certificate request":\
`kubectl get certificaterequests.cert-manager.io -n default`

Certificate request generated "Order":\
`kubectl get orders.acme.cert-manager.io -n default`

>At the step "Challenge" your domain is validated. If there were no problems at all stages, the output
>`kubectl get challenges.acme.cert-manager.io -n default` will return "No resources found in default namespace."

If challenge stuck at "Pending" state run `kubectl describe challenges.acme.cert-manager.io -n default`\
there are you can see reason of pending state.

Finally if everything is fine you can request a production certificate.
Run `kubectl apply -f issuer_prod.yml`
Check status of issuer and modify new_nginx_ingress.yml:
In `cert-manager.io/cluster-issuer:` field set `"letsencrypt-prod"` - the name of production issuer and run
`kubectl apply -f new_nginx_ingress.yml`

To print all about certificates run:
`kubectl get Issuers,ClusterIssuers,Certificates,CertificateRequests,Orders,Challenges -A`

You can find all private keys and certificate at Rancher UI -> "Cluster Project" -> "Resources -> "Secrets"

> Note: Rancher does not support all of resources created via kubectl, but in Rancher UI it is only possible to use 
> the default ingress controller certificate. Anyway, in the case of certificates, there are no problems.