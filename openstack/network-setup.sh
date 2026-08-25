#!/bin/bash

set -euo pipefail

CONTROL_PLANES=""
WORKERS=""

NETWORK_NAME="k8s-cluster"
SUBNET_NAME="k8s-subnet"
SUBNET_CIDR="10.0.0.0/24"
SECURITY_GROUP_NAME="k8s-cluster"

usage() {
    echo "Usage:"
    echo "  $0 --control-planes ID1,ID2,... --workers ID1,ID2,... [options]"
    echo
    echo "Required:"
    echo "  --control-planes IDS     Comma-separated control-plane VM IDs"
    echo "  --workers IDS            Comma-separated worker VM IDs"
    echo 
    echo "Options:"
    echo "  --network NAME           OpenStack network name"
    echo "  --subnet NAME            OpenStack subnet name"
    echo "  --cidr CIDR              Private subnet CIDR"
    echo "  --security-group NAME    OpenStack security group name"
    echo "  -h, --help               Show this help"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in

        --control-planes)
            CONTROL_PLANES="$2"
            shift 2
            ;;

        --workers)
            WORKERS="$2"
            shift 2
            ;;

        --network)
            NETWORK_NAME="$2"
            shift 2
            ;;

        --subnet)
            SUBNET_NAME="$2"
            shift 2
            ;;

        --cidr)
            SUBNET_CIDR="$2"
            shift 2
            ;;

        --security-group)
            SECURITY_GROUP_NAME="$2"
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

if [[ -z "$CONTROL_PLANES" ]]; then
    echo "Error: --control-planes is required"
    exit 1
fi

if [[ -z "$WORKERS" ]]; then
    echo "Error: --workers is required"
    exit 1
fi

echo " Kubernetes OpenStack Network Setup"

echo "Control planes : $CONTROL_PLANES"
echo "Workers        : $WORKERS"
echo "Network        : $NETWORK_NAME"
echo "Subnet         : $SUBNET_NAME"
echo "CIDR           : $SUBNET_CIDR"
echo "Security Group : $SECURITY_GROUP_NAME"
echo


# Create network

echo "[1/5] Creating network..."

openstack network create "$NETWORK_NAME" \
    --description "Private network for Kubernetes cluster"


# Create subnet

echo "[2/5] Creating subnet..."

openstack subnet create "$SUBNET_NAME" \
    --network "$NETWORK_NAME" \
    --subnet-range "$SUBNET_CIDR"


# Create security group

echo "[3/5] Creating security group..."

openstack security group create "$SECURITY_GROUP_NAME"


# Security group rules

echo "[4/5] Creating security group rules..."

# SSH
openstack security group rule create \
    --protocol tcp \
    --dst-port 22 \
    --remote-ip 0.0.0.0/0 \
    "$SECURITY_GROUP_NAME"

# Kubernetes API Server
openstack security group rule create \
    --protocol tcp \
    --dst-port 6443 \
    --remote-ip "$SUBNET_CIDR" \
    "$SECURITY_GROUP_NAME"

# Kubelet
openstack security group rule create \
    --protocol tcp \
    --dst-port 10250 \
    --remote-ip "$SUBNET_CIDR" \
    "$SECURITY_GROUP_NAME"

# Calico VXLAN
openstack security group rule create \
    --protocol udp \
    --dst-port 4789 \
    --remote-ip "$SUBNET_CIDR" \
    "$SECURITY_GROUP_NAME"

# Calico BGP
openstack security group rule create \
    --protocol tcp \
    --dst-port 179 \
    --remote-ip "$SUBNET_CIDR" \
    "$SECURITY_GROUP_NAME"

# Kubernetes NodePort
echo "Allowing Kubernetes NodePort range..."
openstack security group rule create \
    --protocol tcp \
    --dst-port 30000:32767 \
    --remote-ip "$SUBNET_CIDR" \
    "$SECURITY_GROUP_NAME"

# Attach network + security group to control planes

echo "[5/5] Connecting VMs..."

IFS=',' read -ra CP_NODES <<< "$CONTROL_PLANES"

for VM_ID in "${CP_NODES[@]}"; do

    echo "Control plane: $VM_ID"

    openstack server add network \
        "$VM_ID" \
        "$NETWORK_NAME"

    openstack server add security group \
        "$VM_ID" \
        "$SECURITY_GROUP_NAME"

done


# Attach network + security group to workers

IFS=',' read -ra WORKER_NODES <<< "$WORKERS"

for VM_ID in "${WORKER_NODES[@]}"; do

    echo "Worker: $VM_ID"

    openstack server add network \
        "$VM_ID" \
        "$NETWORK_NAME"

    openstack server add security group \
        "$VM_ID" \
        "$SECURITY_GROUP_NAME"

done

echo " K8S Openstack Network setup completed successfully!"