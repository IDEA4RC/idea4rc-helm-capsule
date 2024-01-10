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

## Requirements
In order to deploy this instance, the following will be required:

- Kubernetes instance, either single node or a proper cluster
- Helm needs to be installed (https://helm.sh/docs/intro/install/)
- Istio needs to be deployed (https://istio.io/latest/docs/setup/install/)
- A load balancer needs to be available. Major Cloud providers offer their own load balancers and should be ready to go. On premises solution require a LB such as MetalLB (https://metallb.universe.tf/installation/)
- The Load Balancer needs to be configured with a range of IPs (one at minimum) to provide an IP to the Istio Ingress Gateway. This could be, for eg., a public VIP.

## Configuration
The idea here is to have a Capsule deployment that's as flexible as possible. This means that the user will be able to configure the main components freely and/or to turn on/off specific features. 

The main configuration file is the ```values.yaml``` at the root of the chart. This file contains all the variables used within the chart that are used to generate the actual yaml files that will be fed to Kubernetes. Users can rewrite these values at their leisure. For example, authentication can be disabled simply by setting ```auth_enable: False```, multiple user roles can be defined by altering ```auth_policies```, FHIR docker image changed by replacing the ```fhir.server.image.tag``` with the desired version, Kiali/Prometheus deployment can be turned off, etc. Users are invited to take a look at the ```values.yaml``` file to understand which variables can be interacted with.

Another way to alter the chart configuration is by overriding values when executing the install command by leveraging the ```--set``` switch. Multiple values can be overridden by passing multiple switches.

## How to Deploy
Either clone or download the sources from this repo:
```
git clone https://gitlab.lst.tfo.upm.es/idea4rc/idea4rc-helm-capsule.git
```

Run the install command:
```
helm install idea4rc-capsule idea4rc-helm-capsule
```

Dry run with Auth, Kiali and Prometheus disabled, dump the generated yaml files to dry-run.log:
```
helm install --debug --dry-run idea4rc-capsule idea4rc-helm-capsule/ --set auth_enable=False | tee dry-run.log
```

***

## License
This software is currently licensed under GPLv2 (https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html).
The Kiali and Prometheus templates maintain their original Apache v2 license, as it is code derivated from existing projects. See the files themselves for more info.
