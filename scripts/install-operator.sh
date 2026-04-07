#!/bin/bash

set -euo pipefail

ASTARTE_CHART_VERSION=$1

# Manage Helm repositories
helm repo add astarte https://helm.astarte-platform.org
helm repo update

# Install Astarte Operator
helm install astarte-operator astarte/astarte-operator \
  -n astarte-operator --version "$ASTARTE_CHART_VERSION" \
  --create-namespace || exit 1

# Wait for Astarte Operator to settle
echo "Waiting for Astarte Operator to be created..."
kubectl wait \
  --for=create pod \
  --selector=control-plane=controller-manager \
  --namespace astarte-operator \
  --timeout=90s || exit 1

echo "Waiting for Astarte Operator to be ready..."
kubectl wait \
  --for=condition=ready pod \
  --selector=control-plane=controller-manager \
  --namespace astarte-operator \
  --timeout=90s || exit 1

echo "Astarte Operator is ready!"
