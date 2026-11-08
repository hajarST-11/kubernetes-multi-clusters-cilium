#!/usr/bin/env bash
# Usage : create-user.sh <contexte> <utilisateur> <groupe>
set -euo pipefail
CTX=$1; USR=$2; GRP=$3
DIR=$HOME/projet/users; mkdir -p "$DIR"; cd "$DIR"

# 1. Clé privée et demande de certificat (CN = utilisateur, O = groupe)
openssl genrsa -out "$USR.key" 2048
openssl req -new -key "$USR.key" -out "$USR.csr" -subj "/CN=$USR/O=$GRP"

# 2. Demande de signature envoyée à l'API Kubernetes du cluster
kubectl --context "$CTX" delete csr "$USR" --ignore-not-found
cat <<EOF | kubectl --context "$CTX" apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: $USR
spec:
  request: $(base64 -w0 "$USR.csr")
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400
  usages: ["client auth"]
EOF

# 3. Approbation par l'admin, puis récupération du certificat signé par la CA du cluster
kubectl --context "$CTX" certificate approve "$USR"
until kubectl --context "$CTX" get csr "$USR" -o jsonpath='{.status.certificate}' | grep -q .; do sleep 1; done
kubectl --context "$CTX" get csr "$USR" -o jsonpath='{.status.certificate}' | base64 -d > "$USR.crt"

# 4. Kubeconfig personnel, qui ne connaît QUE ce cluster
SERVER=$(kubectl config view -o jsonpath="{.clusters[?(@.name==\"$CTX\")].cluster.server}")
kubectl config view --raw -o jsonpath="{.clusters[?(@.name==\"$CTX\")].cluster.certificate-authority-data}" \
  | base64 -d > "$CTX-ca.crt"
KC="$DIR/$USR.kubeconfig"
kubectl config --kubeconfig="$KC" set-cluster "$CTX" --server="$SERVER" \
  --certificate-authority="$CTX-ca.crt" --embed-certs=true
kubectl config --kubeconfig="$KC" set-credentials "$USR" \
  --client-certificate="$USR.crt" --client-key="$USR.key" --embed-certs=true
kubectl config --kubeconfig="$KC" set-context "$USR@$CTX" --cluster="$CTX" --user="$USR"
kubectl config --kubeconfig="$KC" use-context "$USR@$CTX"
chmod 600 "$USR.key" "$KC"
echo "OK : $KC"
