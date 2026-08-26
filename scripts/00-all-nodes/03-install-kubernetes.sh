#!/bin/bash

set -euo pipefail

K8S_VERSION=""

usage() {
    echo "Usage:"
    echo "  $0 --version VERSION"
    echo
    echo "Example:"
    echo "  $0 --version v1.30"
    exit 1
}

# Arguments

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)
            K8S_VERSION="$2"
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

if [[ -z "$K8S_VERSION" ]]; then
    usage
fi

# Kubernetes repository
cat > /etc/yum.repos.d/kubernetes.repo <<EOF
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/$K8S_VERSION/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/$K8S_VERSION/rpm/repodata/repomd.xml.key
EOF

# Install Kubernetes
dnf makecache
dnf install -y kubelet kubeadm kubectl

# Enable kubelet
systemctl enable kubelet

# Verify installation
kubelet --version
kubeadm version
kubectl version --client
