# idea4rc-helm-capsule

## Getting started
This helm chart is intended as a way to package and deploy an IDEA4RC Capsule on a Kuberentes instance using Helm (https://helm.sh/). 

## Capsule components
This helm chart contains the following IDEA4RC core Capsule components:
- Istio configurations for Ingress Gateway, Virtual Services and mTLS enforcing
- custom HAPI FHIR instance
- OMOP CDM Instance
- ETL instance (FHIR)
- Capsule Workbench with Internal Reverse Proxy
- Vantage6 Node with custom configuration
- Additional environment config such as ISTIO's, a storageclass, etc.

Vantage6 node is defined as a dependency and will be downloaded during the build process of the chart.
## Requirements

### Hardware Requirements
The capsule requires a server with the following minimal specs (or equivalent resources when deploying on Kubernetes):
- Ubuntu 22.04 VM
- 16 cores
- 16GB of RAM 
- 100GBs of storage

### Network requirements
Repositories that need to be accessible to pull the required Docker images:

- ghcr.io
- quay.io
- docker.io
- registry.k8s.io
- harbor2.vantage6.ai

### Other Requirements
In order to deploy this instance on a Kubernetes cluster, the following software components that are outside of the scope of this chart are required:

- Kubernetes instance, either single node or a proper cluster
- Helm needs to be installed (https://helm.sh/docs/intro/install/)
- Istio needs to be deployed (https://istio.io/latest/docs/setup/install/)
- A load balancer needs to be available. Major Cloud providers offer their own load balancers and should be ready to go. On premises solution require a LB such as MetalLB (https://metallb.universe.tf/installation/). This needs to be configured with a range of IPs (one at minimum) to provide an IP address to the Istio Ingress Gateway, for eg. a public VIP.

### Configuration requirements
To perform the deployment, the following data must be gathered beforehand:

 - CAPSULE_PUB_IP: the IP/FQDN of your Capsule
 - v6node.node.apiKey: the Vantage 6 API Key, provided by the Vantage 6 server operator
 - v6node.node.name: the Vantage 6 node name, provided by the Vantage 6 server operator
 - v6node.node.k8sNodeName: the name of the k8s node where the Vantage 6 client will be executed, for eg. what you get with the following command once k8s has been deployed: ```kubectl get node```
 - fcbexec.keyCloak.clientId: the Keycloak ClientID for the M2M auth of the Query Executor, provided by the external Keycloak operator
 - fcbexec.keyCloak.clientSecret: the Keycloak Client Secret for the M2M auth of the Query Executor, provided by the  external Keycloak operator
 - fcbexec.keyCloak.host: the URL of the Keycloak server, the current default is the CERTH instance for the Idea4RC project
 - fcbexec.kafka.clientId: the Kafka ClientId provided by the Cohort Builder operator
 - fcbexec.kafka.consumerId: the Kafka ConsumerId provided by the Cohort Builder operator
 - certificates for Kafka mTLS Auth used to create the Cohort Builder Query Executor secret

## Chart Structure
The current chart reflects the following structure:
  - Chart.yaml - Helm file that specifies the chart version and its dependiencies
  - values.yaml - the main config file for tha chart, where most of the configuration variables that are of interest to the users are found
  - templates - contains a number of Helm templates that are leveraged to create the Capsule environment, for eg.: the Istio gateway, SSL certificate generation, etc.
  - charts - contains all the different components that compose the Capsule as indicated in the "Capsule components" section above, delivered as sub-charts

## Sub-Charts
In the current release of this chart, each sub-chart can be deployed indipendently from the main one. In fact, each of the charts have their own ```Chart.yaml``` and ```values.yaml``` files. Should the user whish to deploy a single component among those that are packaged as sub-charts, it would be enough to change directory to the correct path, customize the relative ```values.yaml``` file - if necessary - and run the helm install command. 

Components might or might not expect other instances to be available, so bear that in mind when deploying. The following Capsule components are currently served as sub-charts:
- ETL (FHIR)
- Feasibility Cohort Builder Query Executor
- custom HAPI FHIR server
- NLP process
- OMOP CDM
- Workbench

Moreover, this chart deploys the Vantage6 node, too, bundling it as a dependency.

## Configuration
The main concept behind this Helm chart is to have a Capsule deployment that's as easy and flexible as possible. This means that the user will be able to configure the main components freely and/or to turn on/off specific features. 

The main configuration file is the ```values.yaml``` file that's present at the root path of the chart. This file contains all the variables leveraged by Helm, in conjunction with the chart templates, to generate the actual yaml files that will be fed to Kubernetes. Users can override these values at their leisure. For example, ISTIO can be put in PERMISSIVE mode for the datamesh namespace by changing the deafutl value to```istio.mtlsMode: STRICT``` or the HAPI FHIR docker image tag for the FHIR Data server can be changed by replacing the ```fhirDataServer.server.image.tag``` with the desired version and so on and so forth. Users are invited to take a look at the included ```values.yaml``` files to understand which variables can be interacted with.

Another way to alter the chart configuration is by overriding values when executing the install command by leveraging the ```--set``` switch. Multiple values can be overridden by passing multiple instances of this switch. Since this chart is leveraging sub-charts, values can be changed both at sub-chart level or at the main chart level, but do remember that the main ```values.yaml``` file overrides the variables defined in the sub-charts. Some of the required information that is specific to each deployment, for eg. Keycloak authentication info, is also passed to the chart with this method. 

## Endpoints
Once the Capsule has been deployed, the internal services will be available at the endpoints specified in the various virtual services of each component. Looking at the virtual services, we can see that access to internal services is mapped via virtualhosts, for eg. the ETL service will be available at the ```https://$CAPSULE_PUB_IP/datagate/``` URL. In the current release, only the ETL endpoint is published by default. Access to other components can be enabled or disabled by interacting with the relative virtualService variable parameter that can be found in the main ```values.yaml``` file. These changes can be applied either at deployment time or by upgading the chart while passing the proper options.

This is a list of components that are published via Virtual Service, together with their relative prefix path:

| Component | Virtual Service | Endpoint |
|-----------|-----------------|----------|
| ETL (FHIR) | etl-vs | https://CAPSULE_IP/datagate/ |
| Capsule Workbench | revproxy-vs | https://CAPSULE_IP/workbench/ |

### ETL endpoints:
For reference, included here are the endpoints currently exposed by the ETL, presented with a curl example:

Upload data in csv format:
```
curl -vk --location 'https://$CAPSULE_PUB_IP/datagate/etl/upload' --form 'dataFile=@<<your_normalised_table>>.csv'
```

Retrieve uploaded data:
```
curl -vk --location 'https://$CAPSULE_PUB_IP/datagate/etl/data'
```

Gather audit errors:
```
curl -vk --location 'https://$CAPSULE_PUB_IP/datagate/audit/etl-errors'
```

Audit existing records:
```
curl -vk --location 'https://$CAPSULE_PUB_IP/datagate/audit/records'
```

## How to Deploy
> [!IMPORTANT]
> If you wish to ease the deployment, there's an [Ansible playbook](https://github.com/IDEA4RC/microk8s-playbook) that can prepare the environment for you.

> [!TIP]
> A barebones Github Gist that contains all the steps to deply a Capsule from start to finish is available [here](https://gist.github.com/DanielePaviaENG/130f627fe0cb67245055d5c57a5c8d7d).

Either clone or download the sources from this repo:
```
git clone https://github.com/IDEA4RC/idea4rc-helm-capsule
```

Add the Vantage6 Helm repository
```
microk8s.helm repo add vantage6 https://harbor2.vantage6.ai/chartrepo infrastructure
microk8s.helm repo update
```

Update & build the dependencies of the chart:
```
helm dependency update idea4rc-helm-capsule && helm dependency build idea4rc-helm-capsule
```

Deploy the Capsule. You will need to provide the following parameters:
 - CAPSULE_PUB_IP: the IP/FQDN of your Capsule
 - v6node.node.apiKey: the Vantage 6 API Key, provided by the Vantage 6 server operator
 - v6node.node.name: the Vantage 6 node name, provided by the Vantage 6 server operator
 - v6node.node.k8sNodeName: the name of the k8s node where the Vantage 6 client will be executed, for eg. what you get with the following command once k8s has been deployed: ```kubectl get node```
 - fcbexec.keyCloak.clientId: the Keycloak ClientID for the M2M auth of the Query Executor, provided by the external Keycloak operator
 - fcbexec.keyCloak.clientSecret: the Keycloak Client Secret for the M2M auth of the Query Executor, provided by the  external Keycloak operator
 - fcbexec.keyCloak.host: the URL of the Keycloak server, the current default is the CERTH instance for the Idea4RC project
 - fcbexec.kafka.clientId: the Kafka ClientId provided by the Cohort Builder operator
 - fcbexec.kafka.consumerId: the Kafka ConsumerId provided by the Cohort Builder operator
 - certificates for Kafka mTLS Auth used to create the Cohort Builder Query Executor secret
   
Once you have the required values, copy the ```capsule-install.sh``` script included in utils on the parent folder ( with respect to the one that hosts the chart), customize the script with the correct values and execute it to deploy the chart.

> [!IMPORTANT]
> the deployment process does not end with the helm install command. users can execute the command ```kubectl get pods -n datamesh``` on their k8s cluster and wait for every container to start before moving forward.

Once the deployemnt of the chart has been completed, place the certificates provided by the Cohort Builder operator inside the utils forlder and run the script to create the realtive k8s secret:
```
cd idea4rc-helm-capsule/utils/
./query-executor-create-secret.sh
```
Now the OMOP Vocabulary can be created by downloading the file stored in the following GitHub repo:
https://github.com/IDEA4RC/idea4rc-capsule-omop-dictionary/blob/main/idea4rc-capsule-omop-dictionary.dump

And applying it to the Capsule's OMOP instance:
```
omop_pod_name=$(microk8s.kubectl get pods -n datamesh|grep omop|awk '{print $1}')

kubectl exec -i $omop_pod_name --namespace=datamesh -- /bin/bash -c 'pg_restore -U cdm_idea -d omopdb -v' < idea4rc-capsule-omop-dictionary.dump
```

The Capsule is now ready for data injection.

> [!IMPORTANT]
> If you're deploying the Capsule after the execution of the microk8s-playbook, please remember to replace every ```helm``` command with the equivalent ```microk8s.helm```

> [!IMPORTANT]
> Capsule upgrading is unsupported, by design a Capsule should be recreated every time the dataset changes. That means that it should be completely erased with an ```helm delete idea4rc-capsule``` command and redeployed from scratch. 

> [!IMPORTANT]
> When deleting the Capsule to create a fresh deployment from scratch, deletion of all the Persistent Volumes used by the Capsule must occur beforehand. 

## License
This software is currently licensed under GPLv2 (https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html).
