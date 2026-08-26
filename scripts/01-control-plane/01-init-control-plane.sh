#!/bin/bash

set -euo pipefail

if [[ -f /etc/kubernetes/admin.conf ]]; then
    echo "Kubernetes control-plane already initialized"
    exit 0
fi

# Initialize control-plane
systemctl enable --now kubelet

KUBEADM_VERSION=$(kubeadm version -o short)

kubeadm init \
    --pod-network-cidr=192.168.0.0/16 \
    --kubernetes-version="$KUBEADM_VERSION"

# Configure kubectl
mkdir -p /home/almalinux/.kube

cp /etc/kubernetes/admin.conf \
    /home/almalinux/.kube/config

chown -R almalinux:almalinux \
    /home/almalinux/.kube

# Generate certificate key for additional control-planes
CERTIFICATE_KEY=$(kubeadm init phase upload-certs --upload-certs | tail -n 1)

# Generate worker join command
WORKER_JOIN_COMMAND=$(kubeadm token create --print-join-command)

echo "$WORKER_JOIN_COMMAND" > /tmp/k8s-worker-join.sh

# Generate control-plane join command
CONTROL_PLANE_JOIN_COMMAND="$WORKER_JOIN_COMMAND --control-plane --certificate-key $CERTIFICATE_KEY"

echo "$CONTROL_PLANE_JOIN_COMMAND" > /tmp/k8s-control-plane-join.sh

chmod 644 \
    /tmp/k8s-worker-join.sh \
    /tmp/k8s-control-plane-join.sh

echo
echo "Control-plane join command:"
echo "$CONTROL_PLANE_JOIN_COMMAND"
echo
echo "Worker join command:"
echo "$WORKER_JOIN_COMMAND"
# Verify
sudo -u almalinux kubectl \
    --kubeconfig=/home/almalinux/.kube/config \
    get nodes
