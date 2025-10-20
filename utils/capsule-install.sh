# This is an example of a script to deploy the capsule helm chart. Users should adapt it to their own environment.
# This script must be run from the root folder that hosts the idea4rc-helm-capsule folder.

microk8s.helm dependency update idea4rc-helm-capsule && microk8s.helm dependency build idea4rc-h
elm-capsule

export CAPSULE_PUB_IP=<YOUR_IP_ADDRESS_HERE>;

microk8s.helm install idea4rc-capsule idea4rc-helm-capsule/ \
--set capsulePublicHost=$CAPSULE_PUB_IP \
--set istio.tls.commonName=$CAPSULE_PUB_IP \
--set omop.vocabJob=false \
--set v6node.node.apiKey=<VANTAGE6_APIKEY_HERE> \
--set v6node.node.name=<VANTAGE6_NODENAME_HERE> \
--set v6node.node.keycloak.client=<VANTAGE6_KEYCLOAK_CLIENTID_HERE> \
--set v6node.node.keycloak.clientSecret=<VANTAGE6_KEYCLOAK_SECRET_HERE> \
--set v6node.node.keycloakRealm=<VANTAGE6_KEYCLOAK_REALM_HERE> \
--set v6node.node.k8sNodeName=<VANTAGE6_K8S_NODE_NAME_HERE> \
--set v6node.node.keycloakUrl="https://idea4rc-keykloak.development-iti.com/auth" \
--set fcbexec.keyCloak.clientId=<QUERY_EXECUTOR_KEYCLOAK_CLIENTID_HERE> \
--set fcbexec.keyCloak.clientSecret=<QUERY_EXECUTOR_KEYCLOAK_SECRET_HERE> \
--set fcbexec.keyCloak.host="https://idea4rc-keykloak.development-iti.com/auth" \
--set fcbexec.kafka.clientId=<QUERY_EXECUTOR_KAFKA_CLIENTID_HERE> \
--set fcbexec.kafka.consumerId=<QUERY_EXECUTOR_KAFKA_CONSUMERID_HERE>
