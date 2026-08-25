#!/bin/bash

set -e


# Fink Portal - Kubernetes private network setup


# REPLACE these with the actual OpenStack VM IDs
CONTROL_PLANE_ID="REPLACE_WITH_CONTROL_PLANE_VM_ID"
WORKER1_ID="REPLACE_WITH_WORKER1_VM_ID"
WORKER2_ID="REPLACE_WITH_WORKER2_VM_ID"

NETWORK_NAME="fink-portal-k8s-cluster"
SUBNET_NAME="fink-portal-k8s-subnet"
SUBNET_CIDR="10.0.0.0/24"

SECURITY_GROUP_NAME="fink-portal-k8s"

echo "Creating private network..."
openstack network create "$NETWORK_NAME"

echo "Creating subnet..."
openstack subnet create \
    --network "$NETWORK_NAME" \
    --subnet-range "$SUBNET_CIDR" \
    "$SUBNET_NAME"

echo "Creating Kubernetes security group..."
openstack security group create "$SECURITY_GROUP_NAME"

# SSH
echo "Allowing SSH..."
openstack security group rule create \
    --protocol tcp \
    --dst-port 22 \
    --remote-ip 0.0.0.0/0 \
    "$SECURITY_GROUP_NAME"


# Kubernetes API Server
# Private network only
echo "Allowing Kubernetes API server..."
openstack security group rule create \
    --protocol tcp \
    --dst-port 6443 \
    --remote-ip 10.0.0.0/24 \
    "$SECURITY_GROUP_NAME"


# Kubelet
# Private network only
echo "Allowing Kubelet..."
openstack security group rule create \
    --protocol tcp \
    --dst-port 10250 \
    --remote-ip 10.0.0.0/24 \
    "$SECURITY_GROUP_NAME"


# Calico
echo "Allowing Calico BGP..."
openstack security group rule create \
    --protocol tcp \
    --dst-port 179 \
    --remote-ip 10.0.0.0/24 \
    "$SECURITY_GROUP_NAME"

# Calico 
echo "Allowing Calico VXLAN..."
openstack security group rule create \
    --protocol udp \
    --dst-port 4789 \
    --remote-ip 10.0.0.0/24 \
    "$SECURITY_GROUP_NAME"


# NodePort
echo "Allowing Kubernetes NodePort range..."
openstack security group rule create \
    --protocol tcp \
    --dst-port 30000:32767 \
    --remote-ip 10.0.0.0/24 \
    "$SECURITY_GROUP_NAME"


# Attach private network to Kubernetes VMs

echo "Attaching private network to control-plane..."
openstack server add network \
    "$CONTROL_PLANE_ID" \
    "$NETWORK_NAME"

echo "Attaching private network to worker 1..."
openstack server add network \
    "$WORKER1_ID" \
    "$NETWORK_NAME"

echo "Attaching private network to worker 2..."
openstack server add network \
    "$WORKER2_ID" \
    "$NETWORK_NAME"


# Attach security group
echo "Attaching security group to control-plane..."
openstack server add security group \
    "$CONTROL_PLANE_ID" \
    "$SECURITY_GROUP_NAME"

echo "Attaching security group to worker 1..."
openstack server add security group \
    "$WORKER1_ID" \
    "$SECURITY_GROUP_NAME"

echo "Attaching security group to worker 2..."
openstack server add security group \
    "$WORKER2_ID" \
    "$SECURITY_GROUP_NAME"

echo ""
echo "------------------------------------------------------------------"
echo "Kubernetes network setup completed."
echo "Network : $NETWORK_NAME"
echo "Subnet  : $SUBNET_CIDR"
echo "Security Group : $SECURITY_GROUP_NAME"
echo "------------------------------------------------------------------"
