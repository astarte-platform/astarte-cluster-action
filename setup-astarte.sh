#!/bin/bash

tmp_dir=$(mktemp -d -t ci-XXXXXXXXXX)
cd $tmp_dir
wget -q https://github.com/astarte-platform/astartectl/releases/download/v22.11.03/astartectl_22.11.03_linux_x86_64.tar.gz
tar xf astartectl_22.11.03_linux_x86_64.tar.gz
chmod +x astartectl
cd -

export PATH=$tmp_dir:$PATH
# Make it available to the following steps
echo "$tmp_dir" >> $GITHUB_PATH

# Deploy a burst instance
astartectl cluster instances deploy --version "$1" --api-host "api.autotest.astarte-platform.org" --broker-host "broker.autotest.astarte-platform.org" \
    --broker-port 8883 --broker-tls-secret test-certificate --vernemq-volume-size "4G" --rabbitmq-volume-size "4G" \
    --cassandra-volume-size "4G" --name "astarte" --namespace "$2" --burst -y || exit 1

echo "Waiting for Astarte Cluster to be ready..."

# Wait for it to be ready (cluster status must be green), up to 15 minutes
for i in {1..180}; do
    if [[ $(kubectl get astarte -n $2 astarte -o json | jq .status.health -r) = "green" ]]; then
        echo "Astarte cluster reported green status"
        break
    else
        sleep 5
    fi
done

if [[ $(kubectl get astarte -n $2 astarte -o json | jq .status.health -r) != "green" ]]; then
    kubectl get pods -n $2
    kubectl describe astarte astarte -n $2
    kubectl describe pods -n $2 astarte-vernemq-0
    echo "Timed out while waiting for Astarte cluster to report green status"
    exit 1
fi

echo "Configuring Ingress"
# Add the ADI
kubectl apply -n $2 -f $3 || exit 1
# Add the NodePort for the broker
kubectl apply -n $2 -f $4 || exit 1

# Allow a few seconds for the ingress to be configured
sleep 10

echo "Astarte Cluster is ready"
