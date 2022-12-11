#!/bin/sh
clear

set -o errexit

# Fix specified platform
function fix_specified_platform() {
    export DOCKER_DEFAULT_PLATFORM=linux/arm64/v8
    docker build -t tempkind:latest -<<EOF
#FROM --platform=linux/amd64 kindest/node:v1.24.0
FROM --platform=linux/arm64/v8 kindest/node:v1.24.0
RUN arch
EOF
}

# Invoke fix specified platform in otder to create the cluster as linux platform
fix_specified_platform

# create first cluster
cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: k8s-cluster-1
nodes:
- role: control-plane
  image: tempkind:latest
- role: worker
  image: tempkind:latest
networking:
  disableDefaultCNI: true
  podSubnet: "10.0.0.0/16"
  serviceSubnet: "10.1.0.0/16"
EOF

# create second cluster
cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: k8s-cluster-2
nodes:
- role: control-plane
  image: tempkind:latest
- role: worker
  image: tempkind:latest
networking:
  disableDefaultCNI: true
  podSubnet: "10.2.0.0/16"
  serviceSubnet: "10.3.0.0/16"
EOF


helm repo add cilium https://helm.cilium.io/

kubectl config use-context k8s-cluster-1
helm install cilium cilium/cilium --version 1.10.5 \
   --namespace kube-system \
   --set nodeinit.enabled=true \
   --set kubeProxyReplacement=partial \
   --set hostServices.enabled=false \
   --set externalIPs.enabled=true \
   --set nodePort.enabled=true \
   --set hostPort.enabled=true \
   --set cluster.name=k8s-cluster-1 \
   --set cluster.id=1

kubectl config use-context k8s-cluster-2
helm install cilium cilium/cilium --version 1.10.5 \
   --namespace kube-system \
   --set nodeinit.enabled=true \
   --set kubeProxyReplacement=partial \
   --set hostServices.enabled=false \
   --set externalIPs.enabled=true \
   --set nodePort.enabled=true \
   --set hostPort.enabled=true \
   --set cluster.name=k8s-cluster-2 \
   --set cluster.id=2
