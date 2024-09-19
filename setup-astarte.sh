#!/bin/bash

tmp_dir=$(mktemp -d -t ci-XXXXXXXXXX)
cd $tmp_dir
ASTARTECTL_VERSION=$6
wget -q https://github.com/astarte-platform/astartectl/releases/download/v${ASTARTECTL_VERSION}/astartectl_${ASTARTECTL_VERSION}_linux_x86_64.tar.gz
tar xf astartectl_${ASTARTECTL_VERSION}_linux_x86_64.tar.gz
chmod +x astartectl
cd -

export PATH=$tmp_dir:$PATH
# Make it available to the following steps
echo "$tmp_dir" >> $GITHUB_PATH

# Deploy a burst instance
echo "Deploying Astarte"
export ASTARTE_VERSION=$1
cat $5 | envsubst | kubectl apply -n $2 -f - || exit 1

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
