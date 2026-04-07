#!/bin/bash

set -euo pipefail

export ASTARTE_VERSION="$1"
NAMESPACE="$2"
ADI_MANIFEST="$3"
BROKER_MANIFEST="$4"
ASTARTE_MANIFEST="$5"
ASTARTECTL_VERSION="$6"

echo "Creating credential secrets for Scylla..."
kubectl create secret generic scylladb-connection-secret \
  --namespace "$NAMESPACE" \
  --from-literal=username=cassandra \
  --from-literal=password=cassandra

echo "Creating credential secrets for RabbitMQ..."
RABBITMQ_PASSWORD="$(kubectl get secret rabbitmq-default-user -n rabbitmq-system -o jsonpath='{.data.password}' | base64 --decode)"
RABBITMQ_USER="$(kubectl get secret rabbitmq-default-user -n rabbitmq-system -o jsonpath='{.data.username}' | base64 --decode)"
kubectl create secret generic rabbitmq-connection-secret \
  --namespace "$NAMESPACE" \
  --from-literal=username="$RABBITMQ_USER" \
  --from-literal=password="$RABBITMQ_PASSWORD" || exit 1

tmp_dir=$(mktemp -d -t ci-XXXXXXXXXX)
cd $tmp_dir
ASTARTECTL_VERSION=$6
wget -q https://github.com/astarte-platform/astartectl/releases/download/v${ASTARTECTL_VERSION}/astartectl_${ASTARTECTL_VERSION}_linux_x86_64.tar.gz
tar xf astartectl_${ASTARTECTL_VERSION}_linux_x86_64.tar.gz
chmod +x astartectl
cd -

export PATH=$tmp_dir:$PATH
# Make it available to the following steps
echo "$tmp_dir" >> "$GITHUB_PATH"

# Deploy a burst instance
echo "Deploying Astarte"
envsubst < "$ASTARTE_MANIFEST" | kubectl apply -n "$NAMESPACE" -f - || exit 1

# Wait for the Astarte CR to be created
kubectl wait \
  --for=create astarte astarte \
  --namespace "$NAMESPACE" \
  --timeout=90s || exit 1

# Show CR
echo "Astarte CR created:"
kubectl get astarte -n "$NAMESPACE" astarte -o yaml

echo "Waiting for Astarte Cluster to be ready..."

# Wait for it to be ready (cluster status must be green), up to 15 minutes
for i in {1..60}; do
    if [[ $(kubectl get astarte -n "$NAMESPACE" astarte -o json | jq .status.health -r) = "green" ]]; then
        echo "Astarte cluster reported green status"
        break
    else
        echo "Astarte cluster not ready yet, waiting..."
        echo "Current status: "
        kubectl get pods -n "$NAMESPACE"
        echo "Waiting for 15 seconds before checking again..."
        sleep 15
    fi
done

if [[ $(kubectl get astarte -n "$NAMESPACE" astarte -o json | jq .status.health -r) != "green" ]]; then
    kubectl get pods -n "$NAMESPACE"
    kubectl describe astarte astarte -n "$NAMESPACE"
    kubectl describe pod -n "$NAMESPACE" -l app=astarte-appengine-api
    kubectl describe pod -n "$NAMESPACE" -l app=astarte-housekeeping
    kubectl describe pod -n "$NAMESPACE" -l app=astarte-realm-management
    kubectl describe pod -n "$NAMESPACE" -l app=astarte-data-updater-plant
    kubectl describe pod -n "$NAMESPACE" -l app=astarte-pairing
    kubectl describe pod -n "$NAMESPACE" -l app=astarte-trigger-engine
    kubectl describe pod -n "$NAMESPACE" -l app=astarte-vernemq

    kubectl logs -n "$NAMESPACE" deployments/astarte-appengine-api
    kubectl logs -n "$NAMESPACE" deployments/astarte-housekeeping
    kubectl logs -n "$NAMESPACE" deployments/astarte-realm-management
    kubectl logs -n "$NAMESPACE" deployments/astarte-data-updater-plant
    kubectl logs -n "$NAMESPACE" deployments/astarte-pairing
    kubectl logs -n "$NAMESPACE" deployments/astarte-trigger-engine
    kubectl logs -n "$NAMESPACE" statefulsets/astarte-vernemq
    kubectl logs deployments/astarte-operator-controller-manager -n astarte-operator

    echo "Timed out while waiting for Astarte cluster to report green status"
    exit 1
fi

echo "Configuring Ingress"
# Add the ADI
kubectl apply -n "$NAMESPACE" -f "$ADI_MANIFEST"

echo "Waiting for ADI Ingress to be created by the Astarte Operator..."
kubectl wait \
  --for=create ingress adi-api-ingress \
  --namespace "$NAMESPACE" \
  --timeout=90s || exit 1


# Add the NodePort for the broker
kubectl apply -n "$NAMESPACE" -f "$BROKER_MANIFEST"

echo "Waiting for Broker NodePort to be created..."
kubectl wait \
  --for=create service kind-broker-service \
  --namespace "$NAMESPACE" \
  --timeout=90s || exit 1

echo "Astarte Cluster is ready"
