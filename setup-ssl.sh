#!/bin/bash

wget -q -O /tmp/cfssl https://github.com/cloudflare/cfssl/releases/download/v1.6.1/cfssl_1.6.1_linux_amd64
chmod +x /tmp/cfssl
wget -q -O /tmp/cfssljson https://github.com/cloudflare/cfssl/releases/download/v1.6.1/cfssljson_1.6.1_linux_amd64
chmod +x /tmp/cfssljson

mkdir /tmp/astarte-certs
cd /tmp/astarte-certs

/tmp/cfssl gencert -initca $1 | /tmp/cfssljson -bare ca
/tmp/cfssl gencert -ca ca.pem -ca-key ca-key.pem -profile www $2 | /tmp/cfssljson -bare server

# Create Kubernetes secret
kubectl create secret tls test-certificate -n $3 --cert=server.pem --key server-key.pem || exit 1

# Add to runner CA chain
sudo cp ca.pem /usr/local/share/ca-certificates/astarte-autotest.crt
sudo update-ca-certificates || exit 1

rm /tmp/cfssl*
cd -
