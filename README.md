# idea4rc-helm-capsule

## Getting started
This helm chart is intended as a way to package and deploy an IDE4RC capsule on a Kuberentes instance using Helm (https://helm.sh/). 

For a quick start, download this repo and run the following command on your Kubernetes cluster:

```
helm install idea4rc-capsule idea4rc-helm-capsule
```

## Capsule components
This helm chart contains the following IDEA4RC capsule core components:
- Istio configurations for Ingress Gateway, Virtual Services and mTLS enforcing
- FHIR server
- OMOP Instance
- OHDSI API & dependencies
- ETL instance
- Data Extraction instance
- Capsule Workbench
- Interal Reverse Proxy for Web Applications
- Kiali & Prometheus

## Requirements
In order to deploy this instance, the following will be required:

- Kubernetes instance, either single node or a proper cluster
- Helm needs to be installed (https://helm.sh/docs/intro/install/)
- Istio needs to be deployed (https://istio.io/latest/docs/setup/install/)
- A load balancer needs to be available. Major Cloud providers offer their own load balancers and should be ready to go. On premises solution require a LB such as MetalLB (https://metallb.universe.tf/installation/)
- The Load Balancer needs to be configured with a range of IPs (one at minimum) to provide an IP to the Istio Ingress Gateway. This could be, for eg., a public VIP.

## Configuration
The idea here is to have a Capsule deployment that's easy to execute and as flexible as possible. This means that the user will be able to configure the main components freely and/or to turn on/off specific features. 

The main configuration file is the ```values.yaml``` at the root of the chart. This file contains all the variables used within the chart that are used to generate the actual yaml files that will be fed to Kubernetes. Users can override these values at their leisure. For example, keycloack authentication can be disabled simply by setting ```auth_enable: False```, multiple user roles can be defined by altering ```auth_policies```, FHIR docker image changed by replacing the ```fhir.server.image.tag``` with the desired version, Kiali/Prometheus deployment can be turned off, etc. Users are invited to take a look at the ```values.yaml``` file to understand which variables can be interacted with.

Another way to alter the chart configuration is by overriding values when executing the install command by leveraging the ```--set``` switch. Multiple values can be overridden by passing multiple instances of the ```--set``` switch.

> [!WARNING]
> Remember to change/override the default user/passwords in the following "secret" files before installing:
>   - dataextract-postgres-secret.yaml 
>   - etl-postgres-secret.yaml 
>   - fhir-postgres-secret.yaml 
>   - omop-secrets.yaml
>   - celery-secrets.yaml

## Endpoints
Once the capsule has been deployed, the internal services will be available at the endpoints sepcified in the chart's [virtual services template](templates/capsule-vs.yaml). Looking at the virtual services, we can see that access to services is mapped via virtualhosts, for eg. the OHDSI API service will be reached calling the PUBLIC_IP/ohdsi-api/ URL. Currently, all the endpoints will be published by default, but this is not the definitive approach. Once capsule development moves forward, only specific endpoints will be required - if any. 

Users that want to disable specific endpoints can do so either manipulating the virtual service template before deploying the capsule or by editing the virtualservice once the capsule has been already deployed. Once the virtual service is edited, kubernetes will take care of automatically update its execution. To disable a virtual service, it is enough to comment out the unwanted virtualhosts with the classic hash tag "#" at the begging of a line. Live editing of any kubernets object can be achieved by access via kubectl, so, for eg., editing the virtual services of an already deployed capsule can be achieved vie the following command:

```
microk8s.kubectl edit vs -n datamesh idea4rc-vs
```

## How to Deploy

Either clone or download the sources from this repo:
```
git clone https://github.com/IDEA4RC/idea4rc-helm-capsule
```

Run the install command:
```
helm install idea4rc-capsule idea4rc-helm-capsule
```

> [!IMPORTANT]
> If you're deploying the capsule after the execution of the microk8s-playbook, run the following command for a quick start. Note that we're using the checkip.amazonaws.com service to retrieve the VM's public IP for "revproxy.capsule_public_host", we're disabling keystone authentication with auth_enable=False and we're not deploying istio and kiali since that step has already been done via microk8s-playbook.yaml:
> 
> ```
> microk8s.helm install idea4rc-capsule idea4rc-helm-capsule/ --set auth_enable=False --set revproxy.capsule_public_host=$(curl -s checkip.amazonaws.com) --set prometheus_enable=False --set kiali_enable=False | tee install.log
> ```

## How to upgrade
In order to upgrade an existing capsule, downloading the lastest release and upgading it with an ```helm upgrade``` is enough. This Helm chart leverages annotations to trigger the redeployment of the dependencies of the components that have been updated, hence no manual intervention is theoretically required. Also, the "--set" option can be used to override chart values when upgrading too.

Update sources from this repo:
```
git pull https://github.com/IDEA4RC/idea4rc-helm-capsule
```

Run the Helm upgrade command. Using the debug option to dump the contents of the generated templates into a file called upgrade.log:
```
microk8s.helm upgrade --debug idea4rc-capsule idea4rc-helm-capsule/
```

***

## License
This software is currently licensed under GPLv2 (https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html).
The Kiali and Prometheus templates maintain their original Apache v2 license, as it is code derivated from existing projects. See the files themselves for more info.
