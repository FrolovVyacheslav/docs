## Docs: 
https://github.com/Sirius-social/didcomm/blob/main/docs/

## Docker image:
socialsirius/didcomm

To deploy didcomm app firstly need to create a Memcached instance, Redis and PostgreSQL database. 
Mediator contain required variables such as MEMCACHED, DATABASE_HOST, MSG_DELIVERY_SERVICES (Redis host) e.t.c.
For more info see: https://github.com/Sirius-social/didcomm/blob/k8s-deploy-docs/docs/AdminGuide.md

# Create PostgreSQL database, user and password for mediator
Connect to exist PostgreSQL and run:\
`createuser --interactive didcomm_user -W`\
Set role attributes and password.\
`createdb didcomm_db -O didcomm_user`\
Or see Ansible PostgreSQL-master role that which will create everything you need on this step.\
To check the changes run `\l+` in psql cli to list all users and databases.
 
## Create Memcached instance:
In Rancher WEB UI go to cluster -> "Default" project, click to "Resources" -> "Workload" -> "Deploy" and fill in 
the required fields:
- `Name`: name of workload. For example "memcached-instance-1"
- `Docker Image`: memcached:1.6.12
- `Namespace`: default
- `Port Mapping`:
  - `Publish the container port`: by default memcached runs on 11211 port
  - `Protocol`: TCP
  - `As a`: Cluster IP
  - `On listening port`: select the port on which the container will be available (by default is same as container port)

Click to "Save"

## Create 2 Redis instances:
In Rancher WEB UI go to cluster -> "Default" project, click to "Resources" -> "Workload" -> "Deploy" and fill in
the required fields:
- `Name`: name of workload. For example "redis-1"
- `Docker Image`: redis:6.2.6
- `Namespace`: default
- `Port Mapping`:
  - `Publish the container port`: redis default port is 6379
  - `Protocol`: TCP
  - `As a`: Cluster IP
  - `On listening port`: select the port on which the container will be available (by default is same as container port)

Click to "Save", then create a similar Redis-2 instance.

## Create mediator instance:
In Rancher WEB UI go to cluster -> "Default" project, click to "Namespaces" -> "Add Namespace" and create "didcomm" 
namespace.

## Create a Secrets which contain a variables:
Go to "Resources" -> "Secrets" and click "Add Secret"
- `Name`: name of the secret. For example didcomm-env
- `Scope`: availability of the created secret in the cluster (to all namespaces or specify a single namespace)
- `Secrets Values`:
  - `db_password`: the password of the database created above
  - `db_username`: the username of the database created above
  - `fcm_api_key`: Firebase cloud messaging Server API Keys
  - `fcm_sender_id`: Firebase cloud messaging Server API Keys to make able route traffic to mobile devices even OS
  - `seed`: secret seed to generate persistent public key and private key of Mediator App

>Note: To generate seed value run `docker run --rm socialsirius/didcomm manage generate_seed`. This is a 32 byte value.
to check the obtained value, run `echo -n '<SEED>' | wc -c`

## Create a didcomm app:
- `Name`: didcomm
- `Docker Image`: socialsirius/didcomm
- `Namespace`: didcomm
- `Port Mapping`:
  - `Publish the container port`: didcomm app working on 8000 port
  - `Protocol`: TCP
  - `As a`: Cluster IP
  - `On listening port`: select the port on which the container will be available (default is same as container port)

>Note: listening port will be required to create a certificate for the web application. Allow it in cloud firewall.

Than click to "Environment Variables" -> "Add Variable" and create required variables in key:value pair.
>Tips: you can copy and paste key:value pair like "foo = bar" to complete field for variable.

- `DATABASE_HOST`: <postgresql_ip_address>
> Note: do not specify PostgreSQL port - this leads to an error when starting workload.

- `DATABASE_NAME`: database name created in postgresql
- `MEMCACHED`: <name_of_memcached_workload>.default.svc.cluster.local for example memcached-instance-1.default.svc.cluster.local
- `MSG_DELIVERY_SERVICES`: redis://redis-1.default.svc.cluster.local,redis://redis-2.default.svc.cluster.local:6380

Than click to "ADD From Source"
- `Type`: Secret
- `Source`: the secret created earlier (didcomm-env) 
- `Key`: select the secret to be passed to the variable
- `Prefix or Alias`(environments):
  - `DATABASE_USER`
  - `DATABASE_PASSWORD`
  - `SEED`
  - `FCM_API_KEY`
  - `FCM_SENDER_ID`

## [Health Check](https://rancher.com/docs/rancher/v2.0-v2.4/en/v1.6-migration/monitor-apps/):

Click to "Health Check" and set Readiness Check "HTTP request returns a successful status (2xx or 3xx)"
- `Request Path`: /maintenance/health_check
- `Target Container Port`: 80
- `Check Interval`: 5s
- `Healthy After`: 2 successes
- `Start Checking After`: 10s
- `Check Timeout`: 2s
- `Unhealthy After`: 3 failures

> Note: "Readiness Check" is checks if the monitored container is running. If the probe reports failure, Kubernetes 
> kills the pod and then restarts it according to the deployment restart policy. See restart policy 
> in Rancher "Scaling/Upgrade Policy" tab.

Click "Define a separate liveness check" and Set "Liveness Check" "HTTP request returns a successful status
(2xx or 3xx)"
- `Request Path`: /maintenance/liveness_check
- `Target Container Port`: 80
- `Check Interval`: 60s
- `Unhealthy After`: 3 failures
- `Start Checking After`: 10s
- `Check Timeout`: 2s

> Note: "Liveness Check" is checks if the container is ready to accept and serve requests. If the probe reports 
> failure, the pod is sequestered from the public until itself healths.

Click to "Save".

See about [DNS for Services and Pods](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/) in 
Kubernetes documentation for specify deployments via domain name.

Now create certificate. See [create-CA](create-CA.md)
