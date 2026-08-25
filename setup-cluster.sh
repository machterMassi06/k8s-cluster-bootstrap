#!/bin/bash

set -euo pipefail

CONTROL_PLANES=""
WORKERS=""
INTERNAL_NETWORK=""

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
echo " Kubernetes Cluster Setup"

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


# Summary

echo "-----------------------------------------"
echo " Cluster Nodes"
echo "-----------------------------------------"

for NODE in "${NODES[@]}"; do

    IFS='|' read -r ROLE ID NAME INTERNAL_IP PUBLIC_IP <<< "$NODE"

    echo "$ROLE:"
    echo "  $NAME"
    echo "  Internal: $INTERNAL_IP"
    echo "  Public:   $PUBLIC_IP"
    echo

done


echo "Node discovery completed."
echo "-----------------------------------------"

# TODO:
# Execute scripts/00-all-nodes/01-prepare-node.sh
# on each node.