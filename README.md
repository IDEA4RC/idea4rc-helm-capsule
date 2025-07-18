# idea4rc-helm-capsule

## Getting started
This helm chart is intended as a way to package and deploy an IDEA4RC capsule on a Kuberentes instance using Helm (https://helm.sh/). 

## Capsule components
This helm chart contains the following IDEA4RC core capsule components:
- Istio configurations for Ingress Gateway, Virtual Services and mTLS enforcing
- custom HAPI FHIR instance
- OMOP Instance
- ETL instance (FHIR)
- Capsule Workbench
- MariaDB instance called IdeaDB
- Internal Reverse Proxy for internal Web Applications that don't play nice with the ISTIO Virtual Services
- Custom configuration for the Vantage6 Node
- Additional environment config such as ISTIO's, a storageclass, etc.

Vantage6 node is defined as a dependency of the chart and will be download

## Hardware Requirements
The capsule requires a server with the following minimal specs (or equivalent resources when deploying on Kubernetes):
- Ubuntu 22.04 VM
- 16 cores
- 16GB of RAM 
- 80GBs of storage

## Other Requirements
In order to deploy this instance on a Kubernetes cluster, the following software components are required:

- Kubernetes instance, either single node or a proper cluster
- Helm needs to be installed (https://helm.sh/docs/intro/install/)
- Istio needs to be deployed (https://istio.io/latest/docs/setup/install/)
- A load balancer needs to be available. Major Cloud providers offer their own load balancers and should be ready to go. On premises solution require a LB such as MetalLB (https://metallb.universe.tf/installation/). This needs to be configured with a range of IPs (one at minimum) to provide an IP address to the Istio Ingress Gateway, for eg. a public VIP.

Please refer to the "How to Deploy" section for the authentication data required before the deployent can occur.

## Chart Structure
The current chart reflects the following structure:
  - Chart.yaml - Helm file that specifies the chart version and its dependiencies
  - values.yaml - the main config file for tha chart, where most of the configuration variables that are of interest to the users are found
  - templates - contains a number of Helm templates that are leveraged to create the capsule environment, for eg.: the Istio gateway, SSL certificate generation, etc.
  - charts - contains all the different components that compose the capsule as indicated in the "Capsule components" section above, delivered as sub-charts

## Sub-Charts
An interesting feature of the current release is that each sub-chart can be deployed indipendently from the main chart. In fact, each of the charts have their own ```Chart.yaml``` and ```values.yaml``` files. Should the user whish to deploy a single component among those that are packaged as sub-charts, it would be enough to change directory to the correct path, customize the relative ```values.yaml``` file - if necessary - and run the helm install command. 

Components might or might not expect other instances to be available, so bear that in mind when deploying. The following capsule components are currently served as sub-charts:
- ETL (FHIR)
- custom HAPI FHIR server
- IdeaDB
- OMOP CDM
- Capsule Workbench

Moreover, this chart deploys the Vantage6 node, too, bundling it as a dependency.

## Configuration
The main concept behind this Helm chart is to have a capsule deployment that's as easy and flexible as possible. This means that the user will be able to configure the main components freely and/or to turn on/off specific features. 

The main configuration file is the ```values.yaml``` file that's present at the root path of the chart. This file contains all the variables leveraged by Helm, in conjunction with the chart templates, to generate the actual yaml files that will be fed to Kubernetes. As explained in the previous section, users can override these values at their leisure. For example, ISTIO can be put in PERMISSIVE mode for the datamesh namespace by changing the deafutl value to```istio.mtlsMode: STRICT``` or the HAPI FHIR docker image tag for the FHIR Data server can be changed by replacing the ```fhirDataServer.server.image.tag``` with the desired version and so on and so forth. Users are invited to take a look at the included ```values.yaml``` files to understand which variables can be interacted with.

Another way to alter the chart configuration is by overriding values when executing the install command by leveraging the ```--set``` switch. Multiple values can be overridden by passing multiple instances of this switch. Since this chart is leveraging sub-charts, values can be changed both at sub-chart level or at the main chart level, but do remember that the main ```values.yaml``` file overrides the variables defined in the sub-charts. Some of the required information that is specific to each deployment, for eg. Keycloak authentication info, is also passed to the chart with this method. 

## Endpoints
Once the capsule has been deployed, the internal services will be available at the endpoints specified in the various virtual services of each component. Looking at the virtual services, we can see that access to internal services is mapped via virtualhosts, for eg. the ETL service will be available at the ```https://$CAPSULE_PUB_IP/datagate/``` URL. Currently, onlye the ETL endpoint is published by default. Access to other components can be enabled or disabled by interacting with the relative virtualService variable parameter that can be found in the main ```values.yaml``` file. These changes can be applied either at deployment time or by upgading the chart while passing the proper options.

This is a list of components that are published via Virtual Service, together with their relative prefix path:

| Component | Virtual Service | Endpoint |
|-----------|-----------------|----------|
| ETL (FHIR) | etl-vs | | https://CAPSULE_IP/etl/ |
| Capsule Workbench | revproxy-vs | https://CAPSULE_IP/workbench/ |
| OHDSI API | ohdsi-vs | https://CAPSULE_IP/workbench/ |

### ETL endpoints:
For reference, included here are the endpoints currently exposed by the ETL, presented with a curl example:

upload:
```
curl -vk --location 'https://$CAPSULE_PUB_IP/datagate/etl/upload' --form 'dataFile=@<<your_normalised_table>>.csv'
```

get data:
```
curl -vk --location 'https://$CAPSULE_PUB_IP/datagate/etl/data'
```

audit errors:
```
curl -vk --location 'https://$CAPSULE_PUB_IP/datagate/audit/etl-errors'
```

audit records:
```
curl -vk --location 'https://$CAPSULE_PUB_IP/datagate/audit/records'
```

## How to Deploy
> [!IMPORTANT]
> If you wish to ease the deployment, there's an [Ansible playbook](https://github.com/IDEA4RC/microk8s-playbook) that can prepare the environment for you.

> [!IMPORTANT]
> The following Gist is outdated and will not work with this version of the chart

> [!TIP]
> A barebones Github Gist that contains all the basic steps of the capsule deployment from start to finish is available [here](https://gist.github.com/DanielePaviaENG/0356f5f4b02a39ce7e2fdb8298dffb55).

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

Deploy the capsule. You will need to provide the following parameters:
  - capsulePublicHost - the IP or the FQDN pointing to your capsule
  - istio.tls.commonName - the IP or the FQDN pointing to your capsule that will 
  - v6node.node.apiKey - the Vantage6 API that is used to authenticate your node, must be provided by the Vantage6 operators
  - v6node.node.keycloak.client - the Keycloak client ID used by the Vantage6 node for m2m auth, must be provided by the Keycloak operators
  - v6node.node.keycloak.clientSecret - the Keycloak client secret used by the Vantage6 node for m2m auth, must be provided by the Keycloak operators
  - fcbexec.keyCloak.clientId - the Keycloak client ID used by the Feasibility Cohort Builder Query Executor for m2m auth, must be provided by the Keycloak operators
  - fcbexec.keyCloak.clientSecret - the Keycloak client secret used by the Feasibility Cohort Builder Query Executor for m2m auth, must be provided by the Keycloak operators

Once you have the required values, deploy the chart with:
```
helm install idea4rc-capsule idea4rc-helm-capsule/ \
  --set capsulePublicHost=<< your IP or FQDN >> \
  --set istio.tls.commonName=<< your IP or FQDN >> \
  --set v6node.node.apiKey=<<your v6 api key>> \
  --set v6node.node.keycloak.client=<<your keycloak client id>> \
  --set v6node.node.keycloak.clientSecret=<<your keycloak client secret>> \
  --set fcbexec.keyCloak.clientId=<< your cohort builder keycloak client identifier >> \
  --set fcbexec.keyCloak.clientSecret=<< your cohort builder keycloak client secret >>
```

> [!IMPORTANT]
> If you're deploying the capsule after the execution of the microk8s-playbook, please remember to replace ```helm``` with ```microk8s.helm```

## How to upgrade
In order to upgrade an existing capsule:

Update sources from this repo:
```
git pull https://github.com/IDEA4RC/idea4rc-helm-capsule
```

Update & build the dependencies of the chart:
```
helm dependency update idea4rc-helm-capsule && helm dependency build idea4rc-helm-capsule
```

Execute the capsule upgrade:
```
helm install idea4rc-capsule idea4rc-helm-capsule/ \
  --set capsulePublicHost=<< your IP or FQDN >> \
  --set istio.tls.commonName=<< your IP or FQDN >> \
  --set v6node.node.apiKey=<<your v6 api key>> \
  --set v6node.node.keycloak.client=<<your keycloak client id>> \
  --set v6node.node.keycloak.clientSecret=<<your keycloak client secret>> \
  --set fcbexec.keyCloak.clientId=<< your cohort builder keycloak client identifier >> \
  --set fcbexec.keyCloak.clientSecret=<< your cohort builder keycloak client secret >>
```

This Helm chart leverages annotations to trigger the redeployment of the dependencies of the components that have been updated, hence no manual intervention is theoretically required. Please bear in mind that, however, the capsule itself is meant to be not persistent by design. Hence, upgrades are not guaranteed to work and the preferred course of action is to delete and redeploy from scratch, especially when new or updated data is to be uploaded within the capsule.

> [!IMPORTANT]
> When deleting the capsule to create a fresh deployment from scratch, deletion of all the Persistent Volumes used by the capsule must occur beforehand. 

> [!TIP]
> When deploying the capsule, a pretty resource intensive and time consuming job called VocabJob is executed. This job populates the OMOP CDM instance with vocabulary data take from Athena. Should the user wish, for some reason, to skip this execution, using the ```--set omop.vocabJob=false``` option is recommended.

## License
This software is currently licensed under GPLv2 (https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html).