# idea4rc-helm-capsule

## Getting started
This helm chart is intended as a way to package and deploy an IDE4RC capsule on a Kuberentes instance using Helm (https://helm.sh/). 

For a quick start, download this repo and run the following command on your Kubernetes cluster:

```
helm install idea4rc-capsule idea4rc-helm-capsule
```

## Capsule components
This helm chart contains the following IDEA4RC capsule core components:
- FHIR server
- Postgres instance
- Istio configurations for Ingress Gateway and mTLS enforcing
- ETL instance
- Data Extraction instance 
- Aerospike, key/value store used by the ETL
- Kiali and Prometheus, can be enable/disable at deployment time

## Requirements
In order to deploy this instance, the following will be required:

- Kubernetes instance, either single node or a proper cluster
- Helm needs to be installed (https://helm.sh/docs/intro/install/)
- Istio needs to be deployed (https://istio.io/latest/docs/setup/install/)
- A load balancer needs to be available. Major Cloud providers offer their own load balancers and should be ready to go. On premises solution require a LB such as MetalLB (https://metallb.universe.tf/installation/)
- The Load Balancer needs to be configured with a range of IPs (one at minimum) to provide an IP to the Istio Ingress Gateway. This could be, for eg., a public VIP.

## Configuration
The idea here is to have a Capsule deployment that's easy to execute and as flexible as possible. This means that the user will be able to configure the main components freely and/or to turn on/off specific features. 

The main configuration file is the ```values.yaml``` at the root of the chart. This file contains all the variables used within the chart that are used to generate the actual yaml files that will be fed to Kubernetes. Users can rewrite these values at their leisure. For example, keystone authentication can be disabled simply by setting ```auth_enable: False```, multiple user roles can be defined by altering ```auth_policies```, FHIR docker image changed by replacing the ```fhir.server.image.tag``` with the desired version, Kiali/Prometheus deployment can be turned off, etc. Users are invited to take a look at the ```values.yaml``` file to understand which variables can be interacted with.

Another way to alter the chart configuration is by overriding values when executing the install command by leveraging the ```--set``` switch. Multiple values can be overridden by passing multiple instances of the ```--set``` switch.

> [!WARNING]
> Remember to change the default user/passwords in the following "secret" files before installing:
>   - dataextract-postgres-secret.yaml 
>   - etl-postgres-secret.yaml 
>   - fhir-postgres-secret.yaml 
>   - omop-secrets.yaml
>   - celery-secrets.yaml

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
> If you're deploying the capsule following the execution of the microk8s-playbook, run the following command. Note that we're using the checkip.amazonaws.com service to retrieve the VM's public IP for "revproxy.capsule_public_host", we're disabling keystone authentication with auth_enable=False and we're not deploying istio and kiali since that laso already been done via microk8s-playbook.yaml:
> 
> ```
> microk8s.helm install idea4rc-capsule idea4rc-helm-capsule/ --set auth_enable=False --set revproxy.capsule_public_host=$(curl -s checkip.amazonaws.com) --set prometheus_enable=False --set kiali_enable=False | tee install.log
> ```

***

## License
This software is currently licensed under GPLv2 (https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html).
The Kiali and Prometheus templates maintain their original Apache v2 license, as it is code derivated from existing projects. See the files themselves for more info.
