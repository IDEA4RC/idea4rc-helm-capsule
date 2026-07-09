# idea4rc-helm-capsule

## Getting started
This helm chart is intended as a way to package and deploy an IDEA4RC Capsule on a Kuberentes instance using Helm (https://helm.sh/). 

## Capsule components
This helm chart contains the following IDEA4RC core Capsule components:
- Istio configurations for Ingress Gateway, Virtual Services and mTLS enforcing
- custom HAPI FHIR instance
- OMOP CDM Instance
- IDEA ETL instance
- IDEA to OMOP ETL instance
- OMOP to IDEA ETL instance
- Capsule Workbench with internal Apache Reverse Proxy
- Vantage6 Node with custom configuration
- NLP components
- Additional environment config such as ISTIO's, a storageclass, etc.

The Vantage6 node is defined as a dependency and will be downloaded during the build process of the chart.

## Chart Structure
The current chart reflects the following structure:
  - Chart.yaml - Helm file that specifies the chart version and its dependiencies
  - values.yaml - the main config file for tha chart, where most of the configuration variables that are of interest to the users are found
  - templates - contains a number of Helm templates that are leveraged to create the Capsule environment, for eg.: the Istio gateway, SSL certificate generation, etc.
  - charts - contains all the different components that compose the Capsule as indicated in the "Capsule components" section above, delivered as sub-charts

## Sub-Charts
In the current release of this chart, each sub-chart can be deployed indipendently from the main one. In fact, each of the charts have their own ```Chart.yaml``` and ```values.yaml``` files. Should the user whish to deploy a single component among those that are packaged as sub-charts, it would be enough to change directory to the correct path, customize the relative ```values.yaml``` file - if necessary - and run the helm install command. 

Components might or might not expect other instances to be available, so bear that in mind when deploying.

## Chart Structure and Configuration Principles
The main concept behind this Helm chart is to have a Capsule deployment that's as easy and flexible as possible. This means that the user will be able to configure the main components freely and/or to turn on/off specific features. 

The main configuration file is the ```values.yaml``` file that's present at the root path of the chart. This file contains all the variables leveraged by Helm, in conjunction with the chart templates, to generate the actual yaml files that will be fed to Kubernetes. Users can override these values at their leisure. For example, ISTIO can be put in PERMISSIVE mode for the datamesh namespace by changing the defautl value to```istio.mtlsMode: STRICT``` or the HAPI FHIR image tag for the IDEA ETL Data server can be changed by replacing the ```fhirDataServer.server.image.tag``` with the desired version and so on and so forth. Users are invited to take a look at the included ```values.yaml``` files to understand which variables can be interacted with.

Another way to alter the chart configuration is by overriding values when executing the install command by leveraging the ```--set``` switch. Multiple values can be overridden by passing multiple instances of this switch. Since this chart is leveraging sub-charts, values can be changed both at sub-chart level or at the main chart level, but do remember that the main ```values.yaml``` file overrides the variables defined in the sub-charts. Some of the required information that is specific to each deployment, for eg. Keycloak authentication info, is also passed to the chart with this method. 

## Endpoints
Once the Capsule has been deployed, the internal services will be available at the endpoints specified in the various virtual services of each component. Looking at the virtual services, we can see that access to internal services is mapped via virtualhosts, for eg. the ETL service will be available at the ```https://$CAPSULE_PUB_IP/datagate/``` URL. In the current release, only the ETL API endpoint is published by default. Access to other components can be enabled or disabled by interacting with the relative virtualService variable parameter that can be found in the main ```values.yaml``` file. These changes can be applied either at deployment time or by upgading the chart while passing the proper options.

## How to Deploy & Ingest Data

**Scope:** This guide explains how to deploy and operate the IDEA4RC Capsule using the procedures contained in the supplied IDEA4RC Capsule How-To file. The documentation is intentionally verbose and assumes the reader is new to this specific deployment.

**Safety and data-handling warning:** Some audit commands expose sensitive patient-level data. In particular, internal ETL audit logs that are not exposed externally by the Capsule may contain sensitive patient data. Treat all logs, database outputs, dumps, CSV input files, certificates, secrets, and command history as sensitive operational material.

**Suggested use:** Read the requirements first, collect all external credentials and certificates, prepare the MicroK8s environment, deploy the Capsule, create the Query Executor secret, import the OMOP vocabulary, then run one of the documented data ingestion flows.

## 1. Requirements

Before attempting the deployment, verify hardware capacity, network reachability, external service access, and all required configuration values. The Capsule deployment depends on external registries and IDEA4RC services, so a successful Kubernetes installation alone is not sufficient.

### 1.1 Hardware requirements

The deployment target is expected to be an Ubuntu virtual machine with enough CPU, memory, and disk capacity to run MicroK8s, the Capsule workloads, databases, ETL services, Vantage6-related workloads, and supporting services.

- Operating system: Ubuntu 22.04 VM
- CPU: 16 cores
- Memory: 16 GB RAM
- Storage: 80-100 GB – depending on the size of the dataset, this requirement may drastically increase

### 1.2 Container registry network requirements

The Capsule deployment pulls Docker images from multiple registries. If any of these registries are unreachable from the deployment environment, one or more pods not be deployed due to image pull errors and the installation will be unhealthy.

- ghcr.io
- quay.io
- docker.io
- registry.k8s.io
- harbor2.vantage6.ai

The operator should test registry access before Capsule deployment by pulling representative images. These commands should be run from the environment that will need to reach the registries. Passing the test means that every image below can be downloaded successfully.

```bash
docker pull ghcr.io/idea4rc/cohortbuilder-exec
docker pull quay.io/kiali/kiali
docker pull docker.io/aerospike/aerospike-server
docker pull registry.k8s.io/pause:latest
docker pull harbor2.vantage6.ai/infrastructure/node
```

**Expected result:** each docker pull should be completed successfully. If a pull fails, resolve DNS, proxy, firewall, authentication, or outbound connectivity issues before continuing.

### 1.3 IDEA4RC external services that must be reachable

The Capsule is not an isolated local-only stack. It must connect to IDEA4RC services outside the local Kubernetes cluster. The source guide identifies the central orchestrator and CERTH Keycloak as required reachable services.

- Central orchestrator host: `*orchestrator.idea.lst.tfo.upm.es`
- Central orchestrator ports: 9093, 443, and possibly others as indicated in the source guide
- CERTH Keycloak host: `https://idea4rc-keykloak.development-iti.com/auth`
- CERTH Keycloak port: 443

### 1.4 Configuration values that must be collected before deployment

Do not start the Capsule installation until all required values are available. Most of these values are provided by IDEA4RC consortium partners. Missing or incorrect values can result in a Capsule that installs but cannot authenticate, cannot consume Kafka messages, cannot register with Vantage6, or cannot participate correctly in the wider platform.

- **CAPSULE_PUB_IP:** despite the variable name, this represents the local IP address or fully qualified domain name used to access the Capsule.
- **v6node.node.apiKey:** The Vantage6 API key, provided by the Vantage6 server owner (IKNL).
- **v6node.node.name:** The Vantage6 node name, provided by the Vantage6 server owner (IKNL).
- **v6node.node.k8sNodeName:** The Kubernetes node name where the Vantage6 client will be executed. After Kubernetes is deployed, retrieve it with `kubectl get node` or `microk8s.kubectl get node`.
- **fcbexec.keyCloak.clientId:** The Keycloak Client ID for machine-to-machine authentication of the Query Executor, provided by the Keycloak operator (CERTH).
- **fcbexec.keyCloak.clientSecret:** The Keycloak Client Secret for machine-to-machine authentication of the Query Executor, provided by the Keycloak operator (CERTH).
- **fcbexec.keyCloak.host:** The URL of the Keycloak server. The current default is the CERTH instance currently in use for the IDEA4RC project.
- **fcbexec.kafka.clientId:** The Kafka Client ID provided by the Cohort Builder operator (ENG/AlphaHealth).
- **fcbexec.kafka.consumerId:** The Kafka Consumer ID provided by the Cohort Builder operator (Eng/AlphaHealth).
- **Kafka mTLS certificates:** Certificates used to create the Cohort Builder Query Executor secret with `utils/query-executor-create-secret.sh`, provided by the Cohort Builder operator (ENG/AlphaHealth). The operator needs the value of `CAPSULE_PUB_IP` beforehand in order to create the certificates.

## 2. Redeployment principles

Before we begin with the actual deployment itself, it should be noted that, by spec, the Capsule needs to be redeployed from scratch when data changes or when a new release is available. This means that the operator should not treat every update as an in-place modification of the existing installation. The documented redeployment approach is to remove the Helm release and delete persistent volumes before repeating the deployment procedure.

Before running destructive cleanup commands, make sure that all data that must be preserved has been backed up or exported. The command that deletes all persistent volumes is intentionally broad and will remove persistent volumes from the Kubernetes environment.

#### 2.1 Remove an existing Capsule Helm release

**What this step does:** this command asks Helm to delete the Helm release named idea4rc-capsule. The -debug flag increases command output, which can help diagnose uninstall problems.

Command to run:

```bash
microk8s.helm --debug delete idea4rc-capsule
```

**Expected result:** The Helm release named idea4rc-capsule is removed if it exists.

**Important note:** This is part of a destructive redeployment workflow. Do not run it against the wrong cluster or namespace context.

#### 2.2 Delete persistent volumes before a clean redeployment

**What this step does:** This command deletes all Kubernetes persistent volumes visible to the MicroK8s kubectl context.

Command to run:

```bash
microk8s.kubectl delete pv --all
```

**Expected result:** Persistent volumes are deleted, allowing the subsequent deployment to provision fresh storage.

**WARNING:** This command is destructive and broad. Confirm that the cluster is dedicated to this Capsule or that deleting all PVs is acceptable. Be mindful if you need to preserve other volumes that do not belong to the Capsule.

## 3. Deployment workflow overview

At a high level, the deployment follows four phases. Each phase builds on the previous one, so the order matters.

1. Gather all prerequisite information and external credentials.
2. Prepare the Kubernetes environment using the MicroK8s playbook.
3. Deploy the Capsule using the Helm chart.
4. Ingest data through the ETL flow, either CSV to IDEA to OMOP (P2) or OMOP to IDEA (P3).

## 4. Preparing the MicroK8s environment

This section prepares the target machine so that it can run the Capsule. The default flow leverages an Ansible playbook named `microk8s_setup.yml` from the IDEA4RC microk8s-playbook repository. A provisioning node runs Ansible against the host that will become the MicroK8s node. This provisioning node can be the same as the provisioned node.

#### 4.1 Install Ansible on the provisioner node

**What this step does:** Ansible is the automation tool used to run the MicroK8s setup playbook. Install it on the machine from which you will provision the target node.

Command to run:

```bash
sudo apt install -y ansible
```

**Expected result:** The ansible-playbook command becomes available on the provisioner node.

#### 4.2 Copy SSH keys to the node being provisioned

**What this step does:** The playbook needs SSH access to the target host. ssh-copy-id installs your public key into the target user account so Ansible can connect through SSH.

Command to run:

```bash
ssh-copy-id user@hostname
```

**Expected result:** You should be able to connect to user@hostname by SSH without interactive password authentication, depending on your environment policy.

**Important note:** Replace user and hostname with the actual remote username and target host.

#### 4.3 Ensure the remote user has passwordless elevated privileges

**What this step does:** The playbook performs administrative operations. Ansible requires the remote user to be able to elevate privileges without being prompted for a password.

On the node that needs to be provisioned, run:

```bash
sudo usermod -aG adm $USER
```

**Expected result:** The current user is added to the adm group.

**Important note:** it must be stressed that the user should be able to get elevated privileges passwordlessly. Adding the user to adm may not be sufficient in every environment.

#### 4.4 If needed, add a passwordless sudoers rule

**What this step does:** If group membership is not sufficient, adding a sudoers entry could provide the necessary privileges. This allows the specified user to run commands as root without a password prompt, which allows the Ansible automation to proceed.

Add the following line to your `/etc/sudoers` file:

```text
MY_USER  ALL=(ALL:ALL) NOPASSWD: ALL
```

**Expected result:** The specified user can run sudo without being asked for a password.

**Important note:** Edit `/etc/sudoers` safely, preferably with visudo. Replace `MY_USER` with the actual username. This grants broad administrative privileges to the user.

#### 4.5 Clone the MicroK8s playbook repository

**What this step does:** This downloads the Ansible playbook used to configure MicroK8s for the Capsule deployment.

Command to run:

```bash
git clone https://github.com/IDEA4RC/microk8s-playbook
```

**Expected result:** A directory named microk8s-playbook is created in the current working directory.

#### 4.6 Enter the playbook directory

**What this step does:** The ansible-playbook command in the next step is run from inside the cloned repository, where `microk8s_setup.yml` is located.

Command to run:

```bash
cd microk8s-playbook/
```

**Expected result:** Your shell working directory changes to microk8s-playbook.

#### 4.7 Export the public Capsule IP or hostname

**What this step does:** The `CAPSULE_PUB_IP` variable stores the address that will be used to access the Capsule. This is typically the main local IP used to access the VM. The playbook uses this value as the loadbalancer VIP address.

Command to run:

```bash
export CAPSULE_PUB_IP=your_ip
```

**Expected result:** The variable `CAPSULE_PUB_IP` is available in the current shell session.

**Important note:** Replace `your_ip` with the real IP address or FQDN. If the value contains spaces or shellspecial characters, quote it appropriately.

#### 4.8 Run the MicroK8s setup playbook

**What this step does:** This executes the MicroK8s environment preparation using Ansible. The inventory uses a trailing comma to indicate a single host. The extra variable `lb_vip_address` receives the Capsule public IP/FQDN value.

Command to run:

```bash
ansible-playbook -i user@hostname, --extra-vars "lb_vip_address=$CAPSULE_PUB_IP" microk8s_setup.yml
```

**Expected result:** The target host is configured with the MicroK8s environment expected by the Capsule deployment.

**Important note:** Replace user@hostname with the actual SSH target. The shell variable `CAPSULE_PUB_IP` must already be set in this shell.

#### 4.9 Add your user to the microk8s group and restart the session

**What this step does:** Membership in the microk8s group allows a user to interact with MicroK8s without always using sudo. Restart the session after adding the group membership so the new group assignment is applied.

Command to run:

```bash
sudo usermod -a -G microk8s my_user
```

**Expected result:** After logging out and back in, my_user should have the microk8s group membership.

**Important note:** Replace my_user with the actual local user that will operate MicroK8s.

## 5. Deploying the IDEA4RC Capsule with the Helm chart

After the MicroK8s environment has been prepared, deploy the Capsule from the IDEA4RC Helm chart repository. This stage installs the Capsule and then performs additional setup for the Query Executor and OMOP vocabulary.

#### 5.1 Clone the Capsule Helm chart repository

**What this step does:** This downloads the Helm chart repository that contains the Capsule deployment resources and utility scripts.

Command to run:

```bash
git clone https://github.com/IDEA4RC/idea4rc-helm-capsule
```

**Expected result:** A directory named idea4rc-helm-capsule is created.

#### 5.2 Switch to the OMOP ETL development branch

**What this step does:** The deployment should use the omop-etl-dev branch. Enter the repository, switch branch, then return to the parent directory.

Command to run:

```bash
cd idea4rc-helm-capsule/
git switch omop-etl-dev
```

**Expected result:** The local repository is checked out on the omop-etl-dev branch.

#### 5.3 Copy the Capsule installation script

**What this step does:** Copy the capsule-install.sh script into the parent folder before editing and running it. This script is the entrypoint used to run the Helm installation with the required parameters.

Command to run:

```bash
cp utils/capsule-install.sh ../
cd ..
```

**Expected result:** A copy of capsule-install.sh exists in the current directory.

### 5.4 Edit capsule-install.sh with deployment-specific values

Before running the install script, edit it and fill in the values collected during the requirements phase. The script must contain values that match this specific Capsule instance. All of the following data is required:

- CAPSULE_PUB_IP: IP address or FQDN of the Capsule.
- v6node.node.apiKey: Vantage6 API Key.
- v6node.node.name: Vantage6 node name.
- v6node.node.k8sNodeName: Kubernetes node name.
- fcbexec.keyCloak.clientId: Keycloak Client ID for Query Executor M2M authentication.
- fcbexec.keyCloak.clientSecret: Keycloak Client Secret for Query Executor M2M authentication.
- fcbexec.keyCloak.host: Keycloak server URL. The default value is currently correct and only needs to be changed if required.
- fcbexec.kafka.clientId: Kafka Client ID.
- fcbexec.kafka.consumerId: Kafka Consumer ID.

Use the following command to obtain the Kubernetes node name required for `v6node.node.k8sNodeName`:

```bash
microk8s.kubectl get node
```

#### 5.5 Create host paths for the Vantage6 node

**What this step does:** The Vantage6 node needs host directories for logs and tasks. The -p option creates parent directories as needed and does not fail if the directories already exist.

Command to run:

```bash
sudo mkdir -p /var/log/vantage6-node
sudo mkdir -p /mnt/vantage6/tasks
```

**Expected result:** The directories `/var/log/vantage6-node` and `/mnt/vantage6/tasks` exist on the host.

#### 5.6 Make the installation script executable and run it

**What this step does:** chmod +x grants execute permission to the script. Running `./capsule-install.sh` launches the Capsule installation procedure as defined by the script and its configured parameters.

Command to run:

```bash
chmod +x capsule-install.sh
./capsule-install.sh
```

**Expected result:** The Capsule Helm deployment is executed. Kubernetes resources should begin appearing in the cluster.

**Important note:** If the script fails, do not continue with data ingestion. Inspect the script output and Kubernetes resources first.

#### 5.7 Create the Cohort Builder Query Executor secret

**What this step does:** The Query Executor requires a Kubernetes secret built from the provided Kafka mTLS certificates. Copy the certificates provided by the Cohort Builder operator into idea4rc-helm-capsule/utils/ and run the required script.

Command to run:

```bash
cd idea4rc-helm-capsule/utils/
./query-executor-create-secret.sh
```

**Expected result:** A Kubernetes secret required by the Cohort Builder Query Executor is created.

**Important note:** The certificates must be present in the expected utils path before running the script. The certificates are deployment-specific and should be handled as secrets.

#### 5.8 Start the Cohort Builder Query Executor

**What this step does:** The Query Executor deployment is explicitly scaled to one replica. This starts the workload after the required secret has been created.

Command to run:

```bash
kubectl scale --replicas=1 -n datamesh deploy/feasibility-cohort-builder-exec
```

**Expected result:** The deployment feasibility-cohort-builder-exec in namespace datamesh should run one replica.

### 5.9 Download and import the OMOP vocabulary

Download the OMOP dictionary dump into the Capsule, identify the OMOP CDM pod, and then restore the dump into the OMOP database. This step prepares the OMOP vocabulary used by the OMOP CDM and OMOP ETL-related functionality.

Download the OMOP dictionary dump from the following URL:

```text
https://media.githubusercontent.com/media/IDEA4RC/idea4rc-capsule-omopdictionary/refs/heads/main/idea4rc-capsule-omop-dictionary.dump
```

After the file is available locally as `idea4rc-capsule-omop-dictionary.dump`, get the OMOP CDM pod name.

This command lists pods in the datamesh namespace, filters for omop-cdm, and extracts the first column, which is the pod name.

```bash
omop_pod_name=$(microk8s.kubectl get pods -n datamesh | grep omop-cdm | awk '{print $1}')
```

Import the OMOP vocabulary using `pg_restore` inside the OMOP CDM pod. The command attaches standard input to the pod and passes the dump file into pg_restore. The database user is `cdm_idea`, the target database name is `omopdb`, and -v enables verbose restore output to help debug any potential issues.

```bash
microk8s.kubectl exec -i $omop_pod_name --namespace=datamesh -- /bin/bash -c 'pg_restore -U cdm_idea -d omopdb -v' < idea4rc-capsule-omop-dictionary.dump
```

Expected result. `pg_restore` should complete without fatal errors. If restore errors occur, inspect whether the dump file is complete, whether the pod name is correct, and whether the OMOP database is reachable inside the pod. Note that the current vocabulary imports correctly with around 60 role-related errors. This does not preclude the operativity of the Capsule.

## 6. Data ingestion: manual CSV injection, IDEA to OMOP ETL

This section documents injection point 2. It covers direct CSV upload into the IDEA ETL, monitoring of the upload and conversion process, validation of records in the IDEA database, execution of the IDEA-to-OMOP ETL, and final validation in the OMOP CDM database.

#### 6.1 Upload a CSV file into the IDEA ETL

**What this step does:** This curl command sends a CSV file to the ETL upload endpoint exposed under /datagate/etl/upload. The --form argument uploads the file as multipart form data using the field name dataFile. The -k option allows curl to continue even if TLS certificate validation would otherwise fail, and -v enables verbose output.

Command to run:

```bash
curl -vk --location "https://$CAPSULE_PUB_IP/datagate/etl/upload"  --form 'dataFile=@draft01-minus-rows-from-42269.csv'
```

**Expected result:** The ETL service accepts the upload request.

**Important note:** Replace draft01-minus-rows-from-42269.csv with the actual CSV file to ingest. Confirm that `CAPSULE_PUB_IP` is set in the shell before executing this command.

#### 6.2 Check the upload and conversion status

**What this step does:** This command queries the ETL status endpoint. Use it after upload to determine whether the service is still processing the file or has completed the upload/conversion phase.

Command to run:

```bash
curl -vk  "https://$CAPSULE_PUB_IP/datagate/etl/upload/status"
```

**Expected result:** The endpoint returns the current upload/conversion status.

#### 6.3 Retrieve or check the uploaded data prepared by the ETL service

**What this step does:** This command queries the ETL data endpoint. The call returns HTTP 202 when the service acknowledges the request and also while the service is preparing data for transfer. Once the data is ready, the endpoint returns HTTP 200 together with the data.

Command to run:

```bash
curl -vk "https://$CAPSULE_PUB_IP/datagate/etl/data"
```

**Expected result:** HTTP 202 means processing is ongoing. HTTP 200 means the prepared data is returned.

#### 6.4 Follow the IDEA ETL process logs

**What this step does:** This step identifies the IDEA ETL pod and follows its logs. Log monitoring is used to wait until the ETL process finishes before starting the next ETL stage.

Command to run:

```bash
etl_pod_name=$(microk8s.kubectl get pods -n datamesh | grep etl-idea | awk '{print $1}')
microk8s.kubectl logs -f -n datamesh $etl_pod_name
```

**Expected result:** The ETL logs stream to the terminal. Wait until the logs indicate the process has completed.

#### 6.5 Count converted patients in the IDEA database

**What this step does:** This validation query checks how many patient records exist in the IDEA ETL database after the conversion. It obtains an ETL pod name and runs psql inside that pod against database `etl` as user `etl`.

Command to run:

```bash
etl_pod=$(microk8s.kubectl get pods -n datamesh | grep etl | awk '{print $1}' | head -1)
microk8s.kubectl exec -i $etl_pod -n datamesh -- psql -U etl -d etl  -c "SELECT count(*) FROM patient;"
```

**Expected result:** The query returns a count from the patient table.

**Important note:** this check **does not validate the correct data ingestion**, but it represents a useful hint toward understanding if the ingestion has had any major issue. Please read the process logs and share them with the appropriate technical people to ensure the conversion has worked properly.

#### 6.6 Start the IDEA DB to OMOP ETL process

**What this step does:** Once the IDEA ETL process has terminated, this command scales the `omop-etl` deployment to one replica. This starts the ETL process that moves data from the IDEA format to the OMOP CDM format.

Command to run:

```bash
kubectl scale --replicas=1 -n datamesh deploy/omop-etl
```

**Expected result:** The `omop-etl` deployment starts one replica in the datamesh namespace.

#### 6.7 Check the IDEA-to-OMOP ETL logs

**What this step does:** This step gets the OMOP ETL pod name and retrieves its logs so the operator can inspect progress and detect failures.

Command to run:

```bash
omop_pod_name=$(microk8s.kubectl get pods -n datamesh | grep omop-etl | awk '{print $1}')
kubectl logs -n datamesh $omop_pod_name
```

**Expected result:** The OMOP ETL logs are printed to the terminal.

#### 6.8 Check OMOP ETL metadata batch logs

**What this step does:** this step is an optional troubleshooting check that retrieves data from the metadata database by selecting rows from table `batch_custom_log`. This can help understand batch-level OMOP ETL processing state.

Command to run:

```bash
omop_metadata=$(microk8s.kubectl get pods -n datamesh | grep metadata | awk '{print $1}')
microk8s.kubectl exec -i $omop_metadata -n datamesh -- psql -d metadata -U cdm_idea  -c "SELECT * FROM batch_custom_log;"
```

**Expected result:** Rows from `batch_custom_log` are returned, if available.

#### 6.9 Count converted patients in the OMOP CDM

**What this step does:** This final validation checks the OMOP person table after the IDEA-to-OMOP ETL has run. It obtains the OMOP CDM pod and executes a SQL count against omopdb with user cdm_idea.

Command to run:

```bash
omop_cdm_pod=$(microk8s.kubectl get pods -n datamesh | grep omop-cdm | awk '{print $1}')
microk8s.kubectl exec -i $omop_cdm_pod -n datamesh -- psql -U cdm_idea -d omopdb  -c "SELECT count(*) FROM person;"
```

**Expected result:** The query returns the number of records in OMOP person.

**Important note:** this check **does not validate the correct data ingestion**, but it represents a useful hint toward understanding if the ingestion has had any major issue. Please read the process logs and share them with the appropriate technical people to ensure the conversion has worked properly.

## 7. Data ingestion: OMOP to IDEA ETL from a pre-existing OMOP dump

This section documents injection point 3 of the Capsule. It is used when the starting point is a pre-existing OMOP PostgreSQL dump rather than a CSV file for IDEA-to-OMOP conversion. The process restores OMOP data into the OMOP CDM database and then starts the OMOP-to-IDEA ETL, converting the data into the IDEA format.

#### 7.1 Restore OMOP data from a PostgreSQL dump

**What this step does:** This step gets the OMOP CDM pod name and pipes a local PostgreSQL dump file into psql running inside the OMOP CDM pod. The database user and database name are read from `POSTGRES_USER` and `POSTGRES_DB` inside the pod shell.

Command to run:

```bash
omop_cdm_pod_name=$(microk8s.kubectl get pods -n datamesh | grep omop-cdm | awk '{print $1}')
microk8s.kubectl exec -i $omop_cdm_pod_name --namespace=datamesh -- /bin/bash -c 'psql U $POSTGRES_USER -d $POSTGRES_DB' < my_pgsql_dump.sql
```

**Expected result:** The SQL dump is restored into the OMOP database.

**Important note:** Replace `my_pgsql_dump.sql` with the actual dump file. Confirm that the dump is compatible with the target OMOP database schema by looking at the restore process log.

#### 7.2 Start the OMOP-to-IDEA ETL deployment

**What this step does:** After the PostgreSQL restore process has finished, this scales the `omop2idea-etl` deployment to one replica, starting the ETL job.

Command to run:

```bash
kubectl scale -n datamesh deploy omop2idea-etl --replicas=1
```

**Expected result:** The omop2idea-etl deployment starts.

#### 7.3 Follow OMOP-to-IDEA ETL logs until completion

**What this step does:** This command gets the `omop2idea-etl` pod name and follows its logs. The process is complete when the log reports: `Job: [SimpleJob: [name=omop2IdeaJob]] completed (...).`

Command to run:

```bash
omop2idea_pod_name=$(microk8s.kubectl get pods -n datamesh | grep omop2idea-etl | awk '{print $1}')
kubectl logs -f -n datamesh pod/$omop2idea_pod_name
```

**Expected result:** Logs stream until the ETL completes. Look for the documented completion message and for eventual errors during the process.

## 8. Troubleshooting and operational checks

This is a set of operational commands for checking pod status, Query Executor status, secrets, ETL upgrade operations, and audit logs. These commands should be used when validating deployment health or diagnosing runtime issues and are helpful info to share with technical partners that are offering support with the Capsule.

#### 8.1 Check the status of all pods

**What this step does:** This command lists pods across all namespaces. It is the broadest first check when something appears unhealthy, because it shows pods in Pending, CrashLoopBackOff, ImagePullBackOff, Completed, Running, and other states.

Command to run:

```bash
kubectl get pods -A
```

**Expected result:** All pods across all namespaces are listed. All the pods in the `datamesh` namespace are not in `Pending`, `CrashLoopBackOff`, `ImagePullBackOff` or any other unhealthy state.

#### 8.2 Check Query Executor pod status

**What this step does:** This command filters pods in the datamesh namespace for names containing exec. It is used to find the Query Executor pod status.

Command to run:

```bash
kubectl get pods -n datamesh | grep -i exec
```

**Expected result:** the fcbx pods is listed.

#### 8.3 Follow Query Executor logs

**What this step does:** This command stores the Query Executor pod name in variable `fcbx_pod` and follows its logs. Use it to troubleshoot startup, authentication, Kafka, certificate, or runtime processing errors.

Command to run:

```bash
fcbx_pod=$(microk8s.kubectl get pods -n datamesh | grep exec | awk '{print $1}')
kubectl logs -f -n datamesh pod/$fcbx_pod
```

**Expected result:** The Query Executor logs stream to the terminal.

#### 8.4 Check that the Query Executor secret exists

**What this step does:** This command lists secrets in the datamesh namespace and filters for entries containing exec. It verifies whether the Query Executor secret created by query-executor-create-secret.sh is present.

Command to run:

```bash
kubectl get secret -n datamesh | grep exec
```

**Expected result:** Matching secrets are listed if present.

### 8.5 In-place upgrade of the OMOP ETL image

The step documents an in-place image upgrade for the OMOP ETL without reinstalling the entire Capsule. This can be useful to patch the OMOP ETL on-the-fly. Version 5.0.2-AMD is explicitly presented as an example. The sequence scales the deployment down, changes the image, and scales the deployment back up.

```bash
kubectl scale --replicas=0 -n datamesh deploy/omop-etl
kubectl set image -n datamesh  deployment/omop-etl omop-etl=ghcr.io/idea4rc/etlidea2omop:5.0.2-AMD
kubectl scale --replicas=1 -n datamesh deploy/omop-etl
```

**Expected result:** The omop-etl deployment is restarted with image ghcr.io/idea4rc/etl-idea2omop:5.0.2-AMD. Replace the image tag only when a different validated version is required.

**Important:** this is not the correct way to upgrade the Capsule and it is only meant as a way to patch the OMOP ETL on the fly to help with troubleshooting.

### 8.6 ETL audit logs and error inspection

**Important:** ETL audit logs can contain sensitive patient data. Access to these logs should be limited to authorized operators and handled according to the applicable data-protection rules for the deployment environment.

The following audit endpoints are documented as available only from within the IDEA ETL pod itself.

#### 8.6.1 Check ETL errors from inside the IDEA ETL pod

**What this step does:** This curl command queries the local audit endpoint for ETL errors. The endpoint is bound to 127.0.0.1, it must be called from within the IDEA ETL pod as it is not being exposed outside of the Capsule for security and privacy reasons. The operator needs to open a shell inside the pod and then execute the following command.

Command to run:

```bash
curl -vk "http://127.0.0.1/audit/etl-errors"
```

**Expected result:** The endpoint returns any ETL error if this information is available.

**Important note:** The returned data may contain sensitive patient data.

#### 8.6.2 Audit available records from inside the IDEA ETL pod

**What this step does:** This curl command queries the audit endpoint for available data records together with the IDEA ID of persisted resources. The endpoint is bound to 127.0.0.1, it must be called from within the IDEA ETL pod as it is not being exposed outside of the Capsule for security and privacy reasons. The operator needs to open a shell inside the pod and then execute the following command.

Command to run:

```bash
curl -vk "http://127.0.0.1/audit/records"
```

**Expected result:** The endpoint returns available data record audit information if available.

**Important note:** The returned data may contain sensitive patient data.

#### 8.6.3 Retrieve ETL errors from outside the pod using Aerospike tools

**What this step does:** as an alternative to the above way to retrieve IDEA ETL errors, this command starts a temporary pod using the aerospike/aerospike-tools image, connects to the Aerospike service in the `datamesh` namespace, and runs an AQL query against table `idea4rc.EtlProcessError`. The --rm option removes the temporary pod after it exits, -it attaches an interactive terminal, and --restart=Never prevents Kubernetes from recreating it.

Command to run:

```bash
kubectl run aerospike-tools   -n datamesh  --rm -it  --restart=Never   -image=aerospike/aerospike-tools -- aql -h aerospike-svc.datamesh.svc.cluster.local -p 3000 -c "select * from idea4rc.EtlProcessError;"
```

**Expected result:** The AQL query prints ETL process error records if present.

**Important note:** The returned data may contain sensitive patient data.

## 9. Optional tool: k9s for easier MicroK8s cluster interaction

It is optionally recommended to leverage k9s to simplify interactive Kubernetes cluster inspection. This is not required for the Capsule to run, but it can make it easier for operators to inspect pods, logs, namespaces, and resources.

#### 9.1 Install k9s on Ubuntu

**What this step does:** This command downloads the latest k9s Debian package from GitHub, installs it with dpkg, and removes the downloaded package file afterward.

Command to run:

```bash
wget https://github.com/derailed/k9s/releases/latest/download/k9s_linux_amd64.deb && sudo dpkg -i ./k9s_linux_amd64.deb && rm k9s_linux_amd64.deb
```

**Expected result:** k9s is installed on the host.

#### 9.2 Create a kubectl wrapper for MicroK8s kubectl

**What this step does:** Some tools like k9s expect a `kubectl` executable, which might not be available when using MicroK8s. Create an executable wrapper in `/usr/local/bin/kubectl` that executes `/snap/bin/microk8s.kubectl` and passes through all arguments.

Create an executable wrapper in `/usr/local/bin/kubectl` with the following contents:

```bash
#!/bin/bash
exec /snap/bin/microk8s.kubectl "$@"
```

Make it executable:

```bash
chmod  +x /usr/local/bin/kubectl
```

**Expected result:** The wrapper script allows commands that call `kubectl` to use MicroK8s `kubectl`.

#### 9.3 Generate a kubeconfig file in the user home directory

**What this step does:** This command exports the MicroK8s kubeconfig into ~/.kube/config so tools that use the standard Kubernetes configuration path such as k9s can connect to the cluster.

Command to run:

```bash
microk8s.config > ~/.kube/config
```

**Expected result:** A kubeconfig file is written to ~/.kube/config.

**Important note:** Ensure the ~/.kube directory exists before running the command if it has not already been created.
