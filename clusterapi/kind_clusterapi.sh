#!/bin/sh
# Source: https://kind.sigs.k8s.io/docs/user/local-registry/
clear

set -o errexit

# ----------------------------------
# Fix specified platform
function fix_specified_platform() {
    export DOCKER_DEFAULT_PLATFORM=linux/arm64/v8
    docker build -t tempkind:latest -<<EOF
FROM --platform=linux/arm64/v8 kindest/node:v1.24.0
RUN arch
EOF
}

# ----------------------------------
echo "Creating docker image..."
fix_specified_platform
# ----------------------------------

cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: worker
  image: tempkind:latest
- role: control-plane
  image: tempkind:latest
  extraMounts:
    - hostPath: /var/run/docker.sock
      containerPath: /var/run/docker.sock
EOF
# ----------------------------------
