#!/bin/sh
clear

CILIUM_VERSION="1.12.4"
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

echo "Creating first cluster..."

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

echo "Creating second cluster..."
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

echo "Adding Cilium repo..."
kubectl config use-context kind-k8s-cluster-1
helm repo add cilium https://helm.cilium.io/

echo "Installing Cilium in cluster-1..."
kubectl config use-context kind-k8s-cluster-1
helm install cilium cilium/cilium --version ${CILIUM_VERSION} \
   --namespace kube-system \
   --set nodeinit.enabled=true \
   --set kubeProxyReplacement=partial \
   --set hostServices.enabled=false \
   --set externalIPs.enabled=true \
   --set nodePort.enabled=true \
   --set hostPort.enabled=true \
   --set cluster.name=kind-k8s-cluster-1 \
   --set cluster.id=1

echo "Installing Cilium in cluster-2..."
kubectl config use-context kind-k8s-cluster-2
helm install cilium cilium/cilium --version ${CILIUM_VERSION} \
   --namespace kube-system \
   --set nodeinit.enabled=true \
   --set kubeProxyReplacement=partial \
   --set hostServices.enabled=false \
   --set externalIPs.enabled=true \
   --set nodePort.enabled=true \
   --set hostPort.enabled=true \
   --set cluster.name=kind-k8s-cluster-2 \
   --set cluster.id=2
