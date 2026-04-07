#!/bin/bash

set -euo pipefail
CA_CERT_JSON=$1
SERVER_CERT_JSON=$2
NAMESPACE=$3

wget -q -O /tmp/cfssl https://github.com/cloudflare/cfssl/releases/download/v1.6.1/cfssl_1.6.1_linux_amd64
chmod +x /tmp/cfssl
wget -q -O /tmp/cfssljson https://github.com/cloudflare/cfssl/releases/download/v1.6.1/cfssljson_1.6.1_linux_amd64
chmod +x /tmp/cfssljson

mkdir /tmp/astarte-certs
cd /tmp/astarte-certs

/tmp/cfssl gencert -initca "$CA_CERT_JSON" | /tmp/cfssljson -bare ca
/tmp/cfssl gencert -ca ca.pem -ca-key ca-key.pem -profile www "$SERVER_CERT_JSON" | /tmp/cfssljson -bare server

# Create Kubernetes secret
kubectl create secret tls test-certificate -n "$NAMESPACE" --cert=server.pem --key server-key.pem || exit 1

# Add to runner CA chain
sudo cp ca.pem /usr/local/share/ca-certificates/astarte-autotest.crt
sudo update-ca-certificates || exit 1

rm /tmp/cfssl*
cd -
