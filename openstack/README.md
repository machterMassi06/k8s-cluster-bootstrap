# OpenStack Kubernetes Internal Network Setup

This directory contains scripts to automate the creation and configuration of the **private/internal network** required for Kubernetes nodes to communicate with each other.The network is used for communication between the **control-plane nodes** and **worker nodes**.

### Prerequisites

Before running the script, make sure you are **authenticated to your OpenStack project** and that the OpenStack CLI is properly configured with your credentials.

### Setup

Run: `./openstack/network-setup.sh -h` 

```text
Usage:

  ./openstack/network-setup.sh --control-planes ID1,ID2,... --workers ID1,ID2,... [options]

Required:

  --control-planes IDS     Comma-separated control-plane VM IDs
  --workers IDS            Comma-separated worker VM IDs

Options:

  --network NAME           OpenStack network name
  --subnet NAME            OpenStack subnet name
  --cidr CIDR              Private subnet CIDR
  --security-group NAME    OpenStack security group name
  -h, --help               Show this help
```

### Example

First, create the required Kubernetes VMs in OpenStack. Then, replace `vm-id-1`, `vm-id-2`, etc. with the **actual OpenStack VM IDs** of the VMs you created.

For example, for a cluster with **2 control-plane (masters) nodes and 2 workers**:

```bash
./openstack/network-setup.sh \
  --control-planes vm-id-1,vm-id-2 \
  --workers vm-id-3,vm-id-4 \
  --network fink-portal-k8s-cluster \
  --subnet fink-portal-k8s-subnet \
  --cidr 10.0.0.0/24 \
  --security-group fink-portal-k8s
```