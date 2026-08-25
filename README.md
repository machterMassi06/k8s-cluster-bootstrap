# Kubernetes Cluster Bootstrap

This directory contains the documentation and automation scripts used to build a Kubernetes cluster from scratch (from empty servers/VMs -- alma9x).

The objective is to provide a reproducible procedure for deploying a production-like Kubernetes cluster with:

- N control-plane (masters) nodes
- N worker nodes
- Container runtime
- kubeadm
- kubelet
- kubectl
- Calico CNI
- NGINX Ingress Controller
- Kubernetes networking configuration
- Basic cluster validation

The cluster can be deployed **Automatically**, by executing the following commande 

```bash 
./setup-cluster.sh --masters VM-ID1,VM-ID2,... --workers VMI-D1,VM-ID2,... --network-internal NETWORK
---
```
