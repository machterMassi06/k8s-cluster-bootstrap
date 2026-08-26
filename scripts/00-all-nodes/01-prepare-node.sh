#!/bin/bash

set -euo pipefail

HOSTNAME=""
NODES=""

usage() {
    echo "Usage:"
    echo "  $0 --hostname HOSTNAME --nodes 'IP1 HOST1,IP2 HOST2,...'"
    exit 1
}
# Arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --hostname)
            HOSTNAME="$2"
            shift 2
            ;;
        --nodes)
            NODES="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown argument: $1"
            usage
            ;;
    esac
done

if [[ -z "$HOSTNAME" || -z "$NODES" ]]; then
    usage
fi

# System update
dnf update -y

hostnamectl set-hostname "$HOSTNAME"

# /etc/hosts
sed -i \
    '/# K8S-CLUSTER-NODES-START/,/# K8S-CLUSTER-NODES-END/d' \
    /etc/hosts

cat >> /etc/hosts <<EOF

# K8S-CLUSTER-NODES-START
$NODES
# K8S-CLUSTER-NODES-END
EOF

# Disable swap

echo "==> Disabling swap..."

swapoff -a

sed -i '/ swap / s/^/#/' /etc/fstab

# loading Kernel modules
cat > /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# Kubernetes networking

cat > /etc/sysctl.d/99-kubernetes.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system

# Required packages

dnf install -y \
    curl \
    wget \
    vim \
    git \
    tar \
    socat \
    conntrack-tools \
    iproute-tc \
    ebtables

echo
