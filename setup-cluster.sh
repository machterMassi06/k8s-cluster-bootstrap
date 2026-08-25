#!/bin/bash

set -euo pipefail

CONTROL_PLANES=""
WORKERS=""
INTERNAL_NETWORK=""

NODES=()
NODES_HOSTS=""

usage() {
    echo "Usage:"
    echo "  $0 --masters ID1,ID2,... --workers ID1,ID2,... --network-internal NETWORK"
    exit 1
}

# Arguments

while [[ $# -gt 0 ]]; do
    case "$1" in
        --masters)
            CONTROL_PLANES="$2"
            shift 2
            ;;

        --workers)
            WORKERS="$2"
            shift 2
            ;;

        --network-internal)
            INTERNAL_NETWORK="$2"
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

if [[ -z "$CONTROL_PLANES" ||
      -z "$WORKERS" ||
      -z "$INTERNAL_NETWORK" ]]; then
    usage
fi


# Get VM information

get_node_info() {

    local VM_ID="$1"

    local VM_NAME
    local INTERNAL_IP
    local PUBLIC_IP

    VM_NAME=$(openstack server show "$VM_ID" \
        -f value \
        -c name)

    # Get private IP from the internal Kubernetes network

    INTERNAL_IP=$(openstack port list \
        --server "$VM_ID" \
        --network "$INTERNAL_NETWORK" \
        -f value \
        -c "Fixed IP Addresses" |
        grep -oP "'ip_address': '\K[0-9.]+" |
        head -n 1)

    if [[ -z "$INTERNAL_IP" ]]; then
        echo "ERROR: No private IP found for VM $VM_ID" >&2
        exit 1
    fi

    # Get public IP

    PUBLIC_IP=$(openstack server show "$VM_ID" \
        -f value \
        -c addresses |
        grep -oP '\b(?:[0-9]{1,3}\.){3}[0-9]{1,3}\b' |
        grep -v "^10\." |
        head -n 1 || true)

    if [[ -z "$PUBLIC_IP" ]]; then
        echo "ERROR: No public IP found for VM $VM_ID" >&2
        exit 1
    fi

    echo "$VM_ID|$VM_NAME|$INTERNAL_IP|$PUBLIC_IP"
}


# Discover nodes

discover_nodes() {

    echo " Kubernetes Cluster Setup"
    echo
    echo "Internal network: $INTERNAL_NETWORK"
    echo

    NODES=()

    # Control planes

    IFS=',' read -ra MASTER_IDS <<< "$CONTROL_PLANES"

    for VM_ID in "${MASTER_IDS[@]}"; do

        NODE_INFO=$(get_node_info "$VM_ID")

        IFS='|' read -r ID NAME INTERNAL_IP PUBLIC_IP <<< "$NODE_INFO"

        NODES+=("control-plane|$ID|$NAME|$INTERNAL_IP|$PUBLIC_IP")
    done

    # Workers

    IFS=',' read -ra WORKER_IDS <<< "$WORKERS"

    for VM_ID in "${WORKER_IDS[@]}"; do

        NODE_INFO=$(get_node_info "$VM_ID")

        IFS='|' read -r ID NAME INTERNAL_IP PUBLIC_IP <<< "$NODE_INFO"

        NODES+=("worker|$ID|$NAME|$INTERNAL_IP|$PUBLIC_IP")
    done
}


# Build /etc/hosts entries

build_nodes_hosts() {

    NODES_HOSTS=""

    for NODE in "${NODES[@]}"; do

        IFS='|' read -r ROLE ID NAME INTERNAL_IP PUBLIC_IP <<< "$NODE"

        if [[ -z "$NODES_HOSTS" ]]; then
            NODES_HOSTS="$INTERNAL_IP $NAME"
        else
            NODES_HOSTS="$NODES_HOSTS"$'\n'"$INTERNAL_IP $NAME"
        fi

    done

    echo "-----------------------------------------"
    echo " Cluster Nodes"
    echo
    echo "$NODES_HOSTS"
    echo
    echo "Node discovery completed."
    echo "-----------------------------------------"
}


# Prepare all nodes

step_00_01_prepare_nodes() {

    local SCRIPT="scripts/00-all-nodes/01-prepare-node.sh"
    
    echo "=> step_00_01_prepare_nodes"

    for NODE in "${NODES[@]}"; do

        IFS='|' read -r ROLE ID NAME INTERNAL_IP PUBLIC_IP <<< "$NODE"

        echo
        echo "Preparing node: $NAME"

        scp -o StrictHostKeyChecking=accept-new \
            "$SCRIPT" \
            "almalinux@$PUBLIC_IP:/tmp/01-prepare-node.sh"

        ssh -o StrictHostKeyChecking=accept-new \
            "almalinux@$PUBLIC_IP" \
            "chmod +x /tmp/01-prepare-node.sh && \
             sudo /tmp/01-prepare-node.sh \
             --hostname '$NAME' \
             --nodes '$NODES_HOSTS'"

        echo "Node $NAME prepared."

    done
}


# Install containerd

step_00_02_install_containerd() {
    echo "=> step_00_02_install_containerd"
    echo "TODO: install containerd" 
}


# Install Kubernetes

step_00_03_install_kubernetes() {
    echo "TODO: install kube" 
}


# Initialize first control plane

step_01_01_init_control_plane() {

    echo "TODO: Initialize first control plane"
}


# Join additional control planes

step_01_02_join_control_planes() {

    echo "TODO: Join additional control planes"
}


# Join workers

step_02_01_join_workers() {

    echo "TODO: Join workers"
}


# Install Calico

step_03_01_install_calico() {

    echo "TODO: Install Calico"
}


# Install NGINX Ingress

step_03_02_install_ingress() {

    echo "TODO: Install NGINX Ingress"
}


# Validate cluster

step_04_01_validate_cluster() {

    echo "TODO: Validate cluster"
}


# Main

main() {

    discover_nodes
    build_nodes_hosts

    step_00_01_prepare_nodes
    step_00_02_install_containerd
    step_00_03_install_kubernetes

    step_01_01_init_control_plane
    step_01_02_join_control_planes

    step_02_01_join_workers

    step_03_01_install_calico
    step_03_02_install_ingress

    step_04_01_validate_cluster
}

main "$@"