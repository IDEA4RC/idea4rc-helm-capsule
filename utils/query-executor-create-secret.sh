echo "You need to place in the current path the following files provided by the manager of the Orchestrator:"
echo " - ca.pem"
echo " - client.cert.pem"
echo " - client.key.pem"

echo "Creating sercret query-executor-kafka-tls-auth"

kubectl create secret -n datamesh generic query-executor-kafka-tls-auth \
  --from-file=ca.pem=./ca.pem \
  --from-file=client.cert.pem=./client.cert.pem \
  --from-file=client.key.pem=./client.key.pem
