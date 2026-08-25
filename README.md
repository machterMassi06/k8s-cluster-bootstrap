# Kubernetes Cluster Bootstrap

This directory contains the documentation and automation scripts used to build a Kubernetes cluster from scratch (from empty servers/VMs).

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

The cluster can be deployed **Automatically**, by executing the provided scripts in the recommended order.
---