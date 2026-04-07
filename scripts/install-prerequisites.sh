#!/bin/bash

set -euo pipefail

CERT_MANAGER_VERSION=$1
HAPROXY_VERSION=$2
RABBITMQ_OPERATOR_VERSION=$3
SCYLLA_OPERATOR_VERSION=$4
ACTION_PATH=$5

# Manage Helm repositories
helm repo add jetstack https://charts.jetstack.io
helm repo add haproxytech https://haproxytech.github.io/helm-charts
helm repo update

# Install cert-manager
kubectl create namespace cert-manager
helm upgrade --install cert-manager jetstack/cert-manager --namespace cert-manager --version "$CERT_MANAGER_VERSION" --set crds.enabled=true || exit 1

# Wait for cert-manager to settle
echo "Waiting for cert-manager to be ready..."
kubectl wait --namespace cert-manager \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/instance=cert-manager \
  --timeout=90s || exit 1

# Install HAProxy Ingress Controller
helm upgrade --install haproxy-kubernetes-ingress haproxytech/kubernetes-ingress \
  --version "$HAPROXY_VERSION" \
  --namespace haproxy-controller \
  --create-namespace \
  --set controller.service.externalTrafficPolicy=Local \
  --set controller.service.type=NodePort \
  --set controller.service.nodePorts.http=32080 \
  --set controller.service.nodePorts.https=32443 \
  --set controller.service.enablePorts.quic=false || exit 1

# Wait for haproxy to settle
echo "Waiting for HAProxy Ingress Controller to be ready..."
kubectl wait --namespace haproxy-controller \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=kubernetes-ingress \
  --timeout=90s || exit 1

# Install RabbitMQ Cluster Operator
kubectl create namespace rabbitmq-system
kubectl apply --server-side -f https://github.com/rabbitmq/cluster-operator/releases/download/"$RABBITMQ_OPERATOR_VERSION"/cluster-operator.yml -n rabbitmq-system

# Wait for RabbitMQ to settle
echo "Waiting for RabbitMQ Operator to be ready..."
kubectl wait --namespace rabbitmq-system \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=rabbitmq-operator \
  --timeout=90s || exit 1

# Create a RabbitMQ cluster
kubectl apply -n rabbitmq-system -f "$GITHUB_ACTION_PATH"/manifests/prerequisites/rabbitmq-cluster.yaml

# Wait for RabbitMQ nodes to be ready
echo "Waiting for RabbitMQ nodes to be created..."

kubectl wait --namespace rabbitmq-system \
  --for=create pod \
  --selector=app.kubernetes.io/name=rabbitmq \
  --timeout=90s || exit 1

echo "Waiting for RabbitMQ nodes to be ready..."

kubectl wait --namespace rabbitmq-system \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=rabbitmq \
  --timeout=90s || exit 1

# Install Scylla Operator
kubectl create namespace scylla-operator
kubectl apply --server-side -f https://raw.githubusercontent.com/scylladb/scylla-operator/"$SCYLLA_OPERATOR_VERSION"/deploy/operator.yaml -n scylla-operator

# Wait for Scylla to settle
echo "Waiting for Scylla Operator to be created..."

kubectl wait --namespace scylla-operator \
  --for=create pod \
  --selector=app.kubernetes.io/instance=scylla-operator \
  --timeout=90s || exit 1

echo "Waiting for Scylla Operator to be ready..."

kubectl wait --namespace scylla-operator \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=webhook-server \
  --timeout=90s || exit 1

kubectl wait --namespace scylla-operator \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/instance=scylla-operator \
  --timeout=90s || exit 1

kubectl apply -n scylla-operator -f "$GITHUB_ACTION_PATH"/manifests/prerequisites/scylla-config.yaml

kubectl wait --namespace scylla-operator \
  --for=create configmap scylladb-config \
  --timeout=90s || exit 1

kubectl apply -n scylla-operator -f "$GITHUB_ACTION_PATH"/manifests/prerequisites/scylla-cluster.yaml

# Wait for Scylla nodes to be ready
echo "Waiting for Scylla nodes to be created..."
kubectl wait --namespace scylla-operator \
  --for=create pod \
  --selector=scylla-operator.scylladb.com/pod-type=scylladb-node \
  --timeout=300s || exit 1

echo "Waiting for Scylla nodes to be ready..."

kubectl wait --namespace scylla-operator \
  --for=condition=ready pod \
  --selector=scylla-operator.scylladb.com/pod-type=scylladb-node \
  --timeout=300s || exit 1

echo "Dependencies installed successfully!"
