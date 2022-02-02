# Creating Kubernetes Didcomm Deployments

## Secrets
>Kubernetes stores secrets in base64 format.
Put your value in command `echo -n <value> | base64` to get base64 format.

See [example of Secret file](didcomm-secret.yml)

## Configmap
Specify Configmap file to connect the services to deploment.

See [example of Configmap file](didcomm-configmap.yml)

## Deployments
Specify Deployment file to run Didcomm application

See [example of Deployment file](didcomm-deployment.yml)

## FIRE
First of all deploy Secrets and ConfigMap files, database and redis instances, and than Didcomm Deployment.
Run `kubectl apply -f <file.yml>`

## TL;TR
To Create certificate see [create-CA](../create-CA.md)

To deploy Didcomm application in Rancher see [mediator](../mediator.md) file
