# Kubernetes Cluster Bootstrap

This directory contains the documentation and automation scripts used to build a Kubernetes cluster from scratch on AlmaLinux 9.x VMs.

The objective is to provide a reproducible procedure for deploying a production-like Kubernetes cluster with:

- N control-plane (master) nodes
- N worker nodes
- containerd
- kubeadm
- kubelet
- kubectl
- Calico CNI
- NGINX Ingress Controller
- Kubernetes networking
- Basic cluster validation

## Deployment methods

There are two ways to use this project.

### 1. OpenStack VMs

If your VMs are hosted on OpenStack, the Kubernetes nodes must first be connected to a shared private network.

See [`openstack/README.md`](openstack/README.md) for the network setup.

Once the private network is configured, the complete cluster (by default k8s v1.30) can be deployed automatically with:

```bash
./setup-cluster.sh \
  --masters VM-ID1,VM-ID2,... \
  --workers VM-ID1,VM-ID2,... \
  --network-internal NETWORK \
  [--k8s-version <K8S_VERSION>] 
```

The `VM-ID` values are the IDs of the VMs already created in OpenStack.

`setup-cluster.sh` discovers the VM names and private/public IPs, connects to the nodes through SSH, and executes the required installation steps.

### 2. Existing VMs without OpenStack

If you already have AlmaLinux 9.x VMs but do not use OpenStack, you can execute the scripts manually.

In this case, the private network between all Kubernetes nodes must already be configured before.

The nodes must be able to communicate with each other using their private IPs.

Apply the scripts in the following order (you you must to prefix each command by `sudo <command>`).

#### Step 1 — Prepare all nodes

Run on **every control-plane and worker node**:

Note : you can get HOSTNAME from your vm by running : `hostname`

```bash
scripts/00-all-nodes/01-prepare-node.sh \
  --hostname HOSTNAME \
  --nodes 'PRIVATE_IP1 HOSTNAME1
PRIVATE_IP2 HOSTNAME2
PRIVATE_IP3 HOSTNAME3'
```

Example:

```bash
scripts/00-all-nodes/01-prepare-node.sh \
  --hostname k8s-control-plane \
  --nodes '10.0.0.10 k8s-control-plane
10.0.0.11 k8s-worker1
10.0.0.12 k8s-worker2'
```

#### Step 2 — Install containerd

Run on **every node**:

```bash
scripts/00-all-nodes/02-install-containerd.sh
```

#### Step 3 — Install Kubernetes packages

Run on **every node**:

```bash
scripts/00-all-nodes/03-install-kubernetes.sh --version <K8S_VERSION>
```

example : 

```bash
scripts/00-all-nodes/03-install-kubernetes.sh --version v1.30
```

#### Step 4 — Initialize the first control-plane

Run on the **first control-plane node**:

```bash
scripts/01-control-plane/01-init-control-plane.sh
```

This initializes the Kubernetes cluster and generates the commands required to join additional nodes.

#### Step 5 — Join additional control-planes

Run on each additional control-plane node (CPLANES_JOIN_COMMAND is printed in the step 4):

```bash
scripts/01-control-plane/02-join-control-plane.sh --join-command <CPLANES_JOIN_COMMAND>
```

#### Step 6 — Join workers

Run on every worker node (WORKERS_JOIN_COMMAND is printed in the step 4):

```bash
scripts/02-workers/01-join-worker.sh --join-command <WORKERS_JOIN_COMMAND>
```

#### Step 7 — Install Calico

Run from the first control-plane node:

```bash
scripts/03-addons/01-install-calico.sh
```

#### Step 8 — Install NGINX Ingress

Run from the first control-plane node:

```bash
scripts/03-addons/02-install-ingress.sh
```

#### Step 9 — Validate the cluster

Run from the first control-plane node:

```bash
scripts/04-validation/01-validate-cluster.sh
```
