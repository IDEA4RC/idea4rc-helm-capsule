# idea4rc-helm-capsule

## Getting started
This helm chart is intended as a way to package and deploy an IDEA4RC capsule on a Kuberentes instance using Helm (https://helm.sh/). 

For a quick start, download this repo and run the following commands on your Kubernetes cluster:

```
helm dependency update idea4rc-helm-capsule && helm dependency build idea4rc-helm-capsule

export CAPSULE_PUB_IP=$(curl -s checkip.amazonaws.com); microk8s.helm install idea4rc-capsule idea4rc-helm-capsule/ --set capsulePublicHost=$CAPSULE_PUB_IP --set istio.tls.commonName=$CAPSULE_PUB_IP
```

## Capsule components
This helm chart contains the following IDEA4RC core capsule components:
- Istio configurations for Ingress Gateway, Virtual Services and mTLS enforcing
- two HAPI FHIR instances, one acts as usual while the other acts as a dictionary for the ETL process
- OMOP Instance
- OHDSI API & dependencies
- FHIR ETL instance
- Data Extraction Jobs instance
- Capsule Workbench instance
- MariaDB instance called IdeaDB

The capsule also provides additional configuration and objects required for a correct execution. In no particular order:
- a namespace for everything deployed by the chart. The default name of this namespace is "datamesh"
- a custom Kubernetes storage class called "idea4rc-hostpath". As the name implies, this uses an hostpath storage class by default. Should the user wish to use a different storage class, the relative changes should be applied to the idea4rc-helm-capsule/templates/capsule-env/idea4rc-storageclass.yaml file and the main idea4rc-helm-capsule/values.yaml file
- custom Istio configuration templates:
  - configuration for an Istio Ingress Gateway through which all the communications in and out of the capsule passes. Every component that exposes an endpoint through this gateway does so by specifying an Istio Virtual Service. For an example, see the idea4rc-helm-capsule/charts/dataextractor/templates/dataextract-virtualservice.yaml template
  - configuration to generate a self-signed certificate at deployment time. This is leveraged by the Istio Ingress Gateway to ensure that all the traffic going in and out of the capsule is encrypted. Should you wish to provide a custom TLS certificate, the relative changes should be applied to the idea4rc-helm-capsule/templates/istio-config/istio-ingress-tls-secret.yaml
  - configuration to enforce mTLS encrypted communication between the capsule components
- an internal Reverse Proxy for Web Applications that don't work properly with the Istio Virtual Services (currently leveraged by the Capsule Workbench component only)
- configuration templates to implement Keycloak authentication. This is just a proof of concept and hasn't really been implemented yet, it is therefore disabled by default

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
An interesting feature of the current release is that each sub-chart can be deployed indipendently from the main chart. In fact, each of the charts have their own Chart.yaml and values.yaml files. Should the user whish to deploy a single component among those that are packaged as sub-charts, it would be enough to change directory to the correct path, customize the relative values.yaml file - if necessary - and run the helm install command. Components might or might not expect other instances to be available, so bear in mind that when deploying. Let's consider the Data Extraction Jobs component, for example. This component requires an HAPI FHIR instance to connect to in order to retrieve the data it needs. Analyzing the values.yaml contained at the idea4rc-helm-capsule/charts/dataextractor path, there will be several default values that the user might wish to change. In this example, we're going to assume that this component is going to be deployed in the "default" namespace (instead of the "datamesh" namespace specified in the chart), that the service that exposes our existing HAPI FHIR instance that we want to connect to is called "fhir-test-svc" (instead of the default "fhir-data-svc") and that our deployment will be called "test-deploy" (instead of the default "dataextractor" name). Once all the correct varibles have been identified, it will only be a matter of moving into the idea4rc-helm-capsule/charts/dataextractor path and executing the following command to deploy our component:

```
helm install dataextractor ./ --set namespace=default --set fhir.service.name=fhir-test-svc --set name=test-deploy
```

As shown in this example, the default values have been overriden with the --set option. At this point our component has been deployed and should have be correctly connected to the existing HAPI FHIR instance that we've specified. Given that we're using sub-charts that are considered dependecies by the main idea4rc-helm-capsule chart, it will be imperative to build them when installing or upgrading the capsule, as demonstrated in the "How to Deploy" section of this README. The following capsule components are currently served as sub-charts:
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

Another way to alter the chart configuration is by overriding values when executing the install command by leveraging the ```--set``` switch. Multiple values can be overridden by passing multiple instances of this switch. Since this chart is leveraging sub-charts, values can be changed both at sub-chart level or at the main chart level, but do remember that the main values.yaml file overrides the variables defined in the sub-charts. For example, let's assume the we want to change the image tag of the Data Extraction Jobs component image. We edit the idea4rc-helm-capsule/charts/dataextractor/values.yaml and replace the server.image variable value with our custom image specs. If we were to deploy the sub-chart indipendently (see the previous section for an example of that), our deployment would use the custom image we provided. However, if we were deploying the whole capsule, the change we introduced would be ignored. That's because in the main values.yaml file that's present in the idea4rc-helm-capsule/ root path, the default value provided by the sub-chart is overridden by the dataextractor.server.image variable. In this case, the correct approach is to either change the dataextractor.server.image variable in the main values.yaml file, or to override it when installing/upgrading the chart by specifing "--set dataextractor.server.image=my_custom_image:1.0" option. 

While this Helm chart makes quite a few assumptions in order to ease the deployment of the capsule, users are strongly invited to take a look at the values used to deploy every component in order to get a good understanding of the characteristics of the deployments present within the chart itself. 

## Endpoints
Once the capsule has been deployed, the internal services will be available at the endpoints specified in the various virtual services of each component. Looking at the virtual services, we can see that access to services is mapped via virtualhosts, for eg. the OHDSI API service will be reached calling the PUBLIC_IP/ohdsi-api/ URL. Currently, all the endpoints will be published by default, but this is not the definitive approach. Once capsule development moves forward, only specific endpoints will be required - if any. 

Users that want to disable specific endpoints can do so either manipulating the virtual service template before deploying the capsule or by editing the virtual service once the capsule has been already deployed. Once the virtual service is edited, kubernetes will take care of automatically update its execution. To disable a virtual service, it is enough to comment out the unwanted virtualhosts with the classic hash tag "#" at the begging of a line. Live editing of any kubernets object can be achieved by access via kubectl, so, for eg., editing the virtual services of an already deployed capsule can be achieved vie the following command:

```
microk8s.kubectl edit vs -n datamesh idea4rc-vs
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

Run the installation command. Note that we're using the checkip.amazonaws.com service to retrieve the VM's public IP for "capsulePublicHost" and we're specifying the common name (CN) that's going to be used to generate the self-signed certificates for the tls configuration. This implies that you could provide a domain name pointing at the capsule instance instead of the IP, if you have one. Another common scenario would be that of a VM that will only be accessible through a private IP. In this case, the IP that needs to be specified is that of the VM itself. Please do note that this must also be the IP given when running the ansible playbook if you did setup the environment this way.
```
export CAPSULE_PUB_IP=$(curl -s checkip.amazonaws.com); microk8s.helm install idea4rc-capsule idea4rc-helm-capsule/ --set capsulePublicHost=$CAPSULE_PUB_IP --set istio.tls.commonName=$CAPSULE_PUB_IP
```

## How to upgrade
In order to upgrade an existing capsule, downloading the lastest release and upgading it with an ```helm upgrade``` should be enough, depending on a number of factors. This Helm chart leverages annotations to trigger the redeployment of the dependencies of the components that have been updated, hence no manual intervention is theoretically required. Also, the "--set" option can be used to override chart values when upgrading too.

Update sources from this repo:
```
git pull https://github.com/IDEA4RC/idea4rc-helm-capsule
```

Run the Helm upgrade command. Using the debug option to dump the contents of the generated templates into a file called upgrade.log:
```
helm upgrade idea4rc-capsule idea4rc-helm-capsule/
```

***

## License
This software is currently licensed under GPLv2 (https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html).
