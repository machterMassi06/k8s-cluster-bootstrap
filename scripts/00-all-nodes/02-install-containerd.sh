#!/bin/bash

set -euo pipefail

# System update
dnf update -y

# Install Docker repository
dnf install -y dnf-plugins-core

dnf config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo

# Install containerd
dnf install -y containerd.io

# Configure containerd
mkdir -p /etc/containerd

containerd config default > /etc/containerd/config.toml

sed -i \
    's/SystemdCgroup = false/SystemdCgroup = true/' \
    /etc/containerd/config.toml

# Start containerd
systemctl enable --now containerd

# Check containerd
systemctl status containerd --no-pager
