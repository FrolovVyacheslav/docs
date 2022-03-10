# Didcomm Helm Chart

## Prerequisites

To deploy didcomm mediator in cluster firstly need to create a Memcached instance, Redis and PostgreSQL database. 
Mediator contain required variables such as MEMCACHED, DATABASE_HOST, MSG_DELIVERY_SERVICES (Redis hosts) e.t.c.

For more info see: https://github.com/Sirius-social/didcomm/blob/k8s-deploy-docs/docs/AdminGuide.md

Create namespace for didcomm mediator in cluster. 
> :warning: Because "Projects" are a concept introduced by Rancher, kubectl does not have the capability to restrict 
> the creation of namespaces to a project the creator has access to.
> This means that when users create a namespaces with ```kubectl```, it may be 
> unusable because kubectl doesn’t require the new namespace to be scoped within a certain project.

More info [Projects and Namespaces with Rancher](https://rancher.com/docs/rancher/v2.5/en/cluster-admin/projects-and-namespaces/)

## Explain Helm Chart
### Chart hierarchy

├── [Chart.yaml](Chart.yaml)\
├── [values.yml](values.yml)\
├── [templates](templates)\
   ├── [didcomm-configmap.yml](templates/didcomm-configmap.yml)\
   ├── [didcomm-deployment.yml](templates/didcomm-deployment.yml)\
   ├── [didcomm-secret.yml](templates/didcomm-secret.yml)\
   └── [didcomm-service.yml](templates/didcomm-service.yml)

## Running command
```
helm install <release_name> helm-didcomm --namespace <release_namespace> \
--set dbPasswd=<pgsql_password> \
--set dbUser=<pgsql_user> \
--set dbName=<pgsql_name> \
--set seed=<seed_value> \
--set psqlHost=<postgresql_host> \
--set memcached=<memcached_service> \
--set redis=<redis_service>
```
