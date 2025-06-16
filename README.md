# idea4rc-helm-capsule

## Getting started
This helm chart is intended as a way to package and deploy an IDEA4RC capsule on a Kuberentes instance using Helm (https://helm.sh/). 

For a quick start, download this repo and run the following commands on your Kubernetes cluster:

```
helm dependency update idea4rc-helm-capsule && helm dependency build idea4rc-helm-capsule --set host="your public IP"

export CAPSULE_PUB_IP=$(curl -s checkip.amazonaws.com); microk8s.helm install idea4rc-capsule idea4rc-helm-capsule/ --set capsulePublicHost=$CAPSULE_PUB_IP --set istio.tls.commonName=$CAPSULE_PUB_IP
```

## Capsule components
This helm chart contains the following IDEA4RC core capsule components:
- Istio configurations for Ingress Gateway, Virtual Services and mTLS enforcing
- two HAPI FHIR instances, one acts as usual while the other acts as a dictionary for the ETL process
- OMOP Instance
- OHDSI API & dependencies
- FHIR ETL instance
- Data Extraction instance
- Capsule Workbench
- A MariaDB instance called IdeaDB
- Internal Reverse Proxy for internal Web Applications that don't play nice with the ISTIO Virtual Services
- Additional environment config such as ISTIO's, a storageclass, etc.

## Requirements
In order to deploy this instance, the following software components are required:

- Kubernetes instance, either single node or a proper cluster
- Helm needs to be installed (https://helm.sh/docs/intro/install/)
- Istio needs to be deployed (https://istio.io/latest/docs/setup/install/)
- A load balancer needs to be available. Major Cloud providers offer their own load balancers and should be ready to go. On premises solution require a LB such as MetalLB (https://metallb.universe.tf/installation/). This needs to be configured with a range of IPs (one at minimum) to provide an IP address to the Istio Ingress Gateway, for eg. a public VIP.

## Chart Structure
The current chart reflects the following structure:
  - Chart.yaml - Helm file that specifies the chart version and its dependiencies
  - values.yaml - the main config file for tha chart, where most of the configuration variables that are of interest to the users are found
  - templates - contains a number of Helm templates that are leveraged to create the capsule environment, for eg.: the Istio gateway, SSL certificate generation, etc.
  - charts - contains all the different components that compose the capsule as indicated in the "Capsule components" section above, delivered as sub-charts

## Sub-Charts
An interesting feature of the current release is that each sub-chart can be deployed indipendently from the main chart. In fact, each of the charts have their own ```Chart.yaml``` and ```values.yaml``` files. Should the user whish to deploy a single component among those that are packaged as sub-charts, it would be enough to change directory to the correct path, customize the relative ```values.yaml``` file - if necessary - and run the helm install command. 

Components might or might not expect other instances to be available, so bear in mind that when deploying. Let's consider the Data Extraction Jobs component, for example. This component requires an HAPI FHIR instance to connect to in order to retrieve the data it needs. Analyzing the values.yaml contained at the i```idea4rc-helm-capsule/charts/dataextractor path```, there will be several default values that the user might wish to change. In this example, we're going to assume that this component is going to be deployed in the ```default``` namespace (instead of the ```datamesh``` namespace specified in the chart), that the service that exposes our existing HAPI FHIR instance that we want to connect to is called ```fhir-test-svc``` (instead of the default ```fhir-data-svc```) and that our deployment will be called ```test-deploy``` (instead of the default ```dataextractor``` name). Once all the correct varibles have been identified, it will only be a matter of moving into the ```idea4rc-helm-capsule/charts/dataextractor``` path and executing the following command to deploy our component:

```
helm install dataextractor ./ --set namespace=default --set fhir.service.name=fhir-test-svc --set name=test-deploy
```

As shown in this example, the default values have been overriden with the ```--set option```. At this point our component has been deployed and should have be correctly connected to the existing HAPI FHIR instance that we've specified. Given that we're using sub-charts that are considered dependecies by the main ```idea4rc-helm-capsule``` chart, it will be imperative to build them when installing or upgrading the capsule, as demonstrated in the "How to Deploy" section of this README. The following capsule components are currently served as sub-charts:
- Data Extraction Jobs
- FHIR ETL
- custom HAPI FHIR server
- IdeaDB
- OHDSI API
- OMOP CDM
- Capsule Workbench

## Configuration
The main concept behind this Helm chart is to have a capsule deployment that's as easy and flexible as possible. This means that the user will be able to configure the main components freely and/or to turn on/off specific features. 

The main configuration file is the ```values.yaml``` file that's present at the root path of the chart. This file contains all the variables leveraged by Helm, in conjunction with the chart templates, to generate the actual yaml files that will be fed to Kubernetes. As explained in the previous section, users can override these values at their leisure. For example, the experimental Keycloack authentication intergation can be eanbled simply by setting ```auth.enable: True```, multiple user roles can be defined by altering the ```auth.policies```, the HAPI FHIR docker image tag for the FHIR Data server can be changed by replacing the ```fhirDataServer.server.image.tag``` with the desired version and so on and so forth. Users are invited to take a look at the included ```values.yaml``` files to understand which variables can be interacted with.

Another way to alter the chart configuration is by overriding values when executing the install command by leveraging the ```--set``` switch. Multiple values can be overridden by passing multiple instances of this switch. Since this chart is leveraging sub-charts, values can be changed both at sub-chart level or at the main chart level, but do remember that the main ```values.yaml``` file overrides the variables defined in the sub-charts. 

## Endpoints
Once the capsule has been deployed, the internal services will be available at the endpoints specified in the various virtual services of each component. Looking at the virtual services, we can see that access to services is mapped via virtualhosts, for eg. the OHDSI API service will iavailable at  ```https://YOUR_IPi/ohdsi-api``` URL. Currently, a number of endpoints will be published by default. Access to other components can be enabled or disabled by interacting with the relative virtualService variable parameter that can be found in the main ```values.yaml``` file. These changes can be applied either at deployment time or by upgading the chart while passing the proper options.

This is a list of components that are published via Virtual Service, together with their relative prefix path:

| Component | Virtual Service | Endpoint |
|-----------|-----------------|----------|
| Data Extraction Jobs | dataextract-vs | https://CAPSULE_IP/dataext/ |
| Data Extraction Jobs (API Docs | dataextract-vs | https://CAPSULE_IP/dataextdocs/ |
| FHIR ETL | etl-vs | | https://CAPSULE_IP/etl/ |
| Capsule Workbench | revproxy-vs | https://CAPSULE_IP/workbench/ |
| OHDSI API | ohdsi-vs | https://CAPSULE_IP/workbench/ |

By default, the HAPI FHIR instance isn't exposed since no direct interaction is expected to happen by the user. However, this can be enabled by setting the ```fhirDataServer.virtualService.enabled``` to true. On the same note, users that want to disable specific endpoints can do so either manipulating the corresponding variables in the ```values.yaml``` file or by leveraging the ```--set``` option as explained in previus sections.

### ETL endpoints:
These are the endpoints currently exposed by the ETL:

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
> If you wish to ease the deployment, there's an [Ansible playbook](https://github.com/IDEA4RC/microk8s-playbook) that can prepare the environment for you. This setup needs a server with the following minimal specs:
> - Ubuntu 22.04 VM
>   - 16 cores
>   - 16GB of RAM 
>   - 80GBs of storage

> [!TIP]
> A barebones Github Gist that contains all the basic steps of the capsule deployment from start to finish is available [here](https://gist.github.com/DanielePaviaENG/0356f5f4b02a39ce7e2fdb8298dffb55).

Either clone or download the sources from this repo:
```
git clone https://github.com/IDEA4RC/idea4rc-helm-capsule
```

Update & build the dependencies of the chart:
```
helm dependency update idea4rc-helm-capsule && helm dependency build idea4rc-helm-capsule
```

> [!IMPORTANT]
> If you're deploying the capsule after the execution of the microk8s-playbook, run the following command for a quick start. Note that we're using the checkip.amazonaws.com service to retrieve the VM's public IP for "revproxy.capsule_public_host" and we're specifying the common name (CN) that's going to be leveraged for the tls configuration. If you want to expose the capsule only on a private network, please specify the desired private IP instead:
> 
> ```
> export CAPSULE_PUB_IP=$(curl -s checkip.amazonaws.com); microk8s.helm install idea4rc-capsule idea4rc-helm-capsule/ --set revproxy.capsule_public_host=$CAPSULE_PUB_IP --set tls.commonName=$CAPSULE_PUB_IP
> ```

## How to upgrade
In order to upgrade an existing capsule, downloading the lastest release and upgading it with an ```helm upgrade``` is enough. This Helm chart leverages annotations to trigger the redeployment of the dependencies of the components that have been updated, hence no manual intervention is theoretically required. Also, the "--set" option can be used to override chart values when upgrading too. For example:

```
export CAPSULE_PUB_IP=$(curl -s checkip.amazonaws.com); microk8s.helm install idea4rc-capsule idea4rc-helm-capsule/ --set revproxy.capsule_public_host=$CAPSULE_PUB_IP --set tls.commonName=$CAPSULE_PUB_IP
```

Update sources from this repo:
```
git pull https://github.com/IDEA4RC/idea4rc-helm-capsule
```

Update & build the dependencies of the chart:
```
helm dependency update idea4rc-helm-capsule && helm dependency build idea4rc-helm-capsule
```

Then run the upgrade command with the proper options.
```
export CAPSULE_PUB_IP=$(curl -s checkip.amazonaws.com); microk8s.helm upgrade idea4rc-capsule idea4rc-helm-capsule/ --set capsulePublicHost=$CAPSULE_PUB_IP --set istio.tls.commonName=$CAPSULE_PUB_IP
```

> [!IMPORTANT]
> When deleting the capsule to create a fresh deployment from scratch, deletion of all the Persistent Volumes used by the capsule must occur beforehand. 

> [!TIP]
> When deploying the capsule, a pretty resource intensive and time consuming job called VocabJob is executed. This job populates the OMOP CDM instance with vocabulary data take from Athena. Should the user wish, for some reason, to skip this execution, using the ```--set omop.vocabJob=false``` option is enough.

***

## License
This software is currently licensed under GPLv2 (https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html).
