#!/bin/bash

set -euo pipefail

CONTROL_PLANES=""
WORKERS=""
INTERNAL_NETWORK=""

NODES=()
NODES_HOSTS=""

K8S_VERSION="v1.30"

CONTROL_PLANE_JOIN_COMMAND=""
WORKER_JOIN_COMMAND=""
FIRST_CONTROL_PLANE_ID=""

usage() {
    echo "Usage:"
    echo "  $0 --masters ID1,ID2,... --workers ID1,ID2,... --network-internal NETWORK [options]"
    echo
    echo "Options:"
    echo "  --k8s-version VERSION    Kubernetes version (default: v1.30)"
    echo "  -h, --help               Show this help"
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

        --k8s-version)
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

    local SCRIPT="scripts/00-all-nodes/02-install-containerd.sh"

    for NODE in "${NODES[@]}"; do

        IFS='|' read -r ROLE ID NAME INTERNAL_IP PUBLIC_IP <<< "$NODE"

        echo
        echo "containerd installation in node: $NAME"

        scp -o StrictHostKeyChecking=accept-new \
            "$SCRIPT" \
            "almalinux@$PUBLIC_IP:/tmp/02-install-containerd.sh"

        ssh -o StrictHostKeyChecking=accept-new \
            "almalinux@$PUBLIC_IP" \
            "chmod +x /tmp/02-install-containerd.sh && \
             sudo /tmp/02-install-containerd.sh"

        echo "Node $NAME : containerd installed. "

    done
    
}


# Install Kubernetes

step_00_03_install_kubernetes() {
    echo "=> step_00_03_install_kuberntes"

    local SCRIPT="scripts/00-all-nodes/03-install-kubernetes.sh"

    for NODE in "${NODES[@]}"; do

        IFS='|' read -r ROLE ID NAME INTERNAL_IP PUBLIC_IP <<< "$NODE"

        echo
        echo "kubernetes installation in node: $NAME"

        scp -o StrictHostKeyChecking=accept-new \
            "$SCRIPT" \
            "almalinux@$PUBLIC_IP:/tmp/03-install-kubernetes.sh"

        ssh -o StrictHostKeyChecking=accept-new \
            "almalinux@$PUBLIC_IP" \
            "chmod +x /tmp/03-install-kubernetes.sh && \
             sudo /tmp/03-install-kubernetes.sh --version $K8S_VERSION"

        echo "Node $NAME : kubernetes installed. "

    done
}


# Initialize first control-plane

step_01_01_init_control_plane() {

    echo "=> step_01_01_init_control_plane"

    local SCRIPT="scripts/01-control-plane/01-init-control-plane.sh"
    local CONTROL_PLANE_JOIN_FILE="/tmp/k8s-control-plane-join.sh"
    local WORKER_JOIN_FILE="/tmp/k8s-worker-join.sh"

    for NODE in "${NODES[@]}"; do

        IFS='|' read -r ROLE ID NAME INTERNAL_IP PUBLIC_IP <<< "$NODE"

        if [[ "$ROLE" != "control-plane" ]]; then
            continue
        fi

        FIRST_CONTROL_PLANE_ID="$ID"

        echo
        echo "Initializing control-plane: $NAME"

        scp -o StrictHostKeyChecking=accept-new \
            "$SCRIPT" \
            "almalinux@$PUBLIC_IP:/tmp/01-init-control-plane.sh"

        ssh -o StrictHostKeyChecking=accept-new \
            "almalinux@$PUBLIC_IP" \
            "chmod +x /tmp/01-init-control-plane.sh && \
             sudo /tmp/01-init-control-plane.sh \
             --version '$K8S_VERSION'"

        scp -o StrictHostKeyChecking=accept-new \
            "almalinux@$PUBLIC_IP:$CONTROL_PLANE_JOIN_FILE" \
            "/tmp/k8s-control-plane-join.sh"

        scp -o StrictHostKeyChecking=accept-new \
            "almalinux@$PUBLIC_IP:$WORKER_JOIN_FILE" \
            "/tmp/k8s-worker-join.sh"

        CONTROL_PLANE_JOIN_COMMAND=$(cat /tmp/k8s-control-plane-join.sh)
        WORKER_JOIN_COMMAND=$(cat /tmp/k8s-worker-join.sh)

        echo "Join commands retrieved."
        break
    done
}

# Join additional control planes

step_01_02_join_control_planes() {

    echo "=> step_01_02_join_control_planes"

    local SCRIPT="scripts/01-control-plane/02-join-control-plane.sh"


    for NODE in "${NODES[@]}"; do

        IFS='|' read -r ROLE ID NAME INTERNAL_IP PUBLIC_IP <<< "$NODE"

        if [[ "$ROLE" != "control-plane" ]]; then
            continue
        fi

        if [[ "$ID" == "$FIRST_CONTROL_PLANE_ID" ]]; then
            continue
        fi

        echo
        echo "Joining control-plane: $NAME"

        scp -o StrictHostKeyChecking=accept-new \
            "$SCRIPT" \
            "almalinux@$PUBLIC_IP:/tmp/02-join-control-plane.sh"

        ssh -o StrictHostKeyChecking=accept-new \
            "almalinux@$PUBLIC_IP" \
            "chmod +x /tmp/02-join-control-plane.sh && \
             sudo /tmp/02-join-control-plane.sh \
             --join-command '$CONTROL_PLANE_JOIN_COMMAND'"

        echo "Control-plane $NAME joined."

    done
}

# join workers to cplane 
step_02_01_join_workers() {

    echo "=> step_02_01_join_workers"

    local SCRIPT="scripts/02-workers/01-join-worker.sh"

    for NODE in "${NODES[@]}"; do

        IFS='|' read -r ROLE ID NAME INTERNAL_IP PUBLIC_IP <<< "$NODE"

        if [[ "$ROLE" != "worker" ]]; then
            continue
        fi

        echo
        echo "Joining worker: $NAME"

        scp -o StrictHostKeyChecking=accept-new \
            "$SCRIPT" \
            "almalinux@$PUBLIC_IP:/tmp/01-join-worker.sh"

        ssh -o StrictHostKeyChecking=accept-new \
            "almalinux@$PUBLIC_IP" \
            "chmod +x /tmp/01-join-worker.sh && \
             sudo /tmp/01-join-worker.sh \
             --join-command '$WORKER_JOIN_COMMAND'"

        echo "Worker $NAME joined."

    done
}


# Install Calico

step_03_01_install_calico() {

    echo "=> step_03_01_install_calico"

    local SCRIPT="scripts/03-addons/01-install-calico.sh"

    for NODE in "${NODES[@]}"; do

        IFS='|' read -r ROLE ID NAME INTERNAL_IP PUBLIC_IP <<< "$NODE"

        if [[ "$ROLE" != "control-plane" ]]; then
            continue
        fi

        echo
        echo "Installing Calico on: $NAME"

        scp -o StrictHostKeyChecking=accept-new \
            "$SCRIPT" \
            "almalinux@$PUBLIC_IP:/tmp/01-install-calico.sh"

        ssh -o StrictHostKeyChecking=accept-new \
            "almalinux@$PUBLIC_IP" \
            "chmod +x /tmp/01-install-calico.sh && \
             sudo /tmp/01-install-calico.sh"

        echo "Calico installed."

        break
    done
}


# Install Ingress (example : NGINX Ingress Controller)

step_03_02_install_ingress() {

    echo "=> step_03_02_install_ingress"

    local SCRIPT="scripts/03-addons/02-install-ingress.sh"

    for NODE in "${NODES[@]}"; do

        IFS='|' read -r ROLE ID NAME INTERNAL_IP PUBLIC_IP <<< "$NODE"

        if [[ "$ROLE" != "control-plane" ]]; then
            continue
        fi

        echo
        echo "Installing NGINX Ingress on: $NAME"

        scp -o StrictHostKeyChecking=accept-new \
            "$SCRIPT" \
            "almalinux@$PUBLIC_IP:/tmp/02-install-ingress.sh"

        ssh -o StrictHostKeyChecking=accept-new \
            "almalinux@$PUBLIC_IP" \
            "chmod +x /tmp/02-install-ingress.sh && \
             sudo /tmp/02-install-ingress.sh"

        echo "NGINX Ingress installed."

        break
    done
}

# Validate cluster

step_04_01_validate_cluster() {

    echo "TODO: Validate cluster"
}


# Main

main() {

    discover_nodes
    build_nodes_hosts

    # STEP 0 -- FOR ALL K8S NODES 
    step_00_01_prepare_nodes
    step_00_02_install_containerd
    step_00_03_install_kubernetes

    # STEP 1 -- JUST FOR K8S CONTROLE PLANE NODES
    step_01_01_init_control_plane
    step_01_02_join_control_planes

    # STEP 2 -- JUST FOR K8S WORKERS NODES
    step_02_01_join_workers

    # STEP 3 -- JUST FOR THE FIRST K8S CONTROLE PLAN NODE 
    step_03_01_install_calico
    step_03_02_install_ingress

    # STEP 4 -- JUST FOR THE FIRST K8S CONTROLE PLAN NODE 
    step_04_01_validate_cluster
}

main "$@"