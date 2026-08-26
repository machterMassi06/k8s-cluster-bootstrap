#!/bin/bash

set -euo pipefail

# Get kubectl acces 
KUBECONFIG="/home/almalinux/.kube/config"
export KUBECONFIG

INGRESS_VERSION="controller-v1.13.2" 
INGRESS_MANIFEST="https://raw.githubusercontent.com/kubernetes/ingress-nginx/${INGRESS_VERSION}/deploy/static/provider/cloud/deploy.yaml"

kubectl apply -f "$INGRESS_MANIFEST"

echo "Waiting for NGINX Ingress Controller..."

kubectl rollout status deployment/ingress-nginx-controller \
    -n ingress-nginx \
    --timeout=300s

kubectl get pods -n ingress-nginx