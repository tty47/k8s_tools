#!/bin/sh
# Source: https://kind.sigs.k8s.io/docs/user/local-registry/
clear

set -o errexit

# Fix specified platform
function fix_specified_platform() {
    export DOCKER_DEFAULT_PLATFORM=linux/arm64/v8
    docker build -t tempkind:latest -<<EOF
#FROM --platform=linux/amd64 kindest/node:v1.25.0
FROM --platform=linux/arm64/v8 kindest/node:v1.25.0
RUN arch
EOF
}

# --------------------------------------------------
# Invoke fix specified platform in otder to create the cluster as linux platform
fix_specified_platform

# --------------------------------------------------
# create a cluster with the local registry enabled in containerd
cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  image: tempkind:latest
- role: worker
  image: tempkind:latest
  extraMounts:
    - hostPath: /var/run/docker.sock
      containerPath: /var/run/docker.sock
EOF

# --------------------------------------------------
# connect the registry to the cluster network
# (the network may already be connected)
docker network connect "kind" "${reg_name}" || true
