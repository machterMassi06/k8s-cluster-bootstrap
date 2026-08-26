#!/bin/bash

set -euo pipefail

CALICO_VERSION="v3.30.3" # this version is compatible with k8s v1.30 -- TODO: pass it as an arg
CALICO_MANIFEST="/tmp/calico.yaml"
KUBECONFIG="/home/almalinux/.kube/config"

curl -fsSL \
    "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml" \
    -o "$CALICO_MANIFEST"

export KUBECONFIG

kubectl apply -f "$CALICO_MANIFEST"


kubectl rollout status daemonset/calico-node \
    -n kube-system \
    --timeout=300s

echo "Waiting for nodes..."

kubectl wait \
    --for=condition=Ready \
    nodes \
    --all \
    --timeout=300s
