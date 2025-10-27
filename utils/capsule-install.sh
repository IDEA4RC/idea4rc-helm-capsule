# Place this script in the parent folder of the idea4rc-helm-capsule folder becfore executing

# You will require the follow data:
# - CAPSULE_PUB_IP: the IP/FQDN of your capsule
# - v6node.node.apiKey: the Vantage 6 API Key, provided by the Vantage 6 server owner
# - v6node.node.name: the Vantage 6 node name, provided by the Vantage 6 server owner
# - v6node.node.k8sNodeName: the name of the k8s node where the Vantage 6 client will be executed, for eg. what you get with: `kubectl get node`
# - fcbexec.keyCloak.clientId: the Keycloak ClientID for the M2M auth of the Query Executor, provided by the Keycloak operator
# - fcbexec.keyCloak.clientSecret: the Keycloak Client Secret for the M2M auth of the Query Executor, provided by the Keycloak operator
# - fcbexec.keyCloak.host: the URL of the KeyCLoak server, the current default is the CERTH instance for the Idea4RC project
# - fcbexec.kafka.clientId: the Kafka ClientId provided by the Cohort Builder operator
# - fcbexec.kafka.consumerId: the Kafka ConsumerId provided by the Cohort Builder operator

# Important: You will also need  to create the Query Executor secret with the certificates provided by the Cohort Builder operator using the utils/query-executor-create-secret.sh script

microk8s.helm dependency update idea4rc-helm-capsule && microk8s.helm dependency build idea4rc-helm-capsule

export CAPSULE_PUB_IP=YOUR_IP;

microk8s.helm install --debug idea4rc-capsule idea4rc-helm-capsule/ \
	--set capsulePublicHost=$CAPSULE_PUB_IP \
	--set istio.tls.commonName=$CAPSULE_PUB_IP \
	--set v6node.node.apiKey="YOUR_API_KEY" \
	--set v6node.node.name="YOUR_NODE_NAME" \
	--set v6node.node.k8sNodeName="YOUR_NODE_NAME" \
	--set fcbexec.keyCloak.clientId="YOUR_QUERY_EXECUTOR_KEYCLOAK_CLIENT" \
	--set fcbexec.keyCloak.clientSecret="YOUR_QUERY_EXECUTOR_KEYCLOAK_SECRET" \
        --set fcbexec.keyCloak.host="https://idea4rc-keykloak.development-iti.com/auth" \
        --set fcbexec.kafka.clientId="YOUR_KAFKA_CLIENTID" \
        --set fcbexec.kafka.consumerId="YOUR_KAFKA_CONSUMERID"
