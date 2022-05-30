#!/bin/sh
# Source: https://kind.sigs.k8s.io/docs/user/local-registry/
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

# Invoke fix specified platform in otder to create the cluster as linux
# platform
fix_specified_platform

# create registry container unless it already exists
reg_name='kind-registry'
reg_port='5000'
running="$(docker inspect -f '{{.State.Running}}' "${reg_name}" 2>/dev/null || true)"
if [ "${running}" != 'true' ]; then
  docker run \
    -d --restart=always -p "127.0.0.1:${reg_port}:5000" --name "${reg_name}" \
    registry:2
fi

#unameOut="$(uname -s)"
#case "${unameOut}" in
#Linux*)     machine="688fba5ce6b825be62a7c7fe1415b35da2bdfbb5a69227c499ea4cc0008661ca";;
#Darwin*)    machine="4c68efafa97d278a75a5b4677fb27e4986b03301739f1f87575af32202da9cfe";;
#*)          machine="UNKNOWN:${unameOut}"
#esac
#echo "OS detected: ${unameOut}"

# create a cluster with the local registry enabled in containerd
cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  image: tempkind:latest
#- role: control-plane
#- role: control-plane
#- role: worker
#- role: worker
- role: worker
  image: tempkind:latest
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:${reg_port}"]
    endpoint = ["http://${reg_name}:5000"]
EOF

# connect the registry to the cluster network
# (the network may already be connected)
docker network connect "kind" "${reg_name}" || true

# Document the local registry
# https://github.com/kubernetes/enhancements/tree/master/keps/sig-cluster-lifecycle/generic/1755-communicating-a-local-registry
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${reg_port}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF

# Setup rometheus if argument is -p
if [[ $1 == "-p" ]];then
	echo "Cloning project to /tmp..."
	git clone https://github.com/jrmanes/linux-tools.git /tmp/linux-tools || true
	echo "Granting permissions..."
	chmod +x /tmp/linux-tools/*.sh
	/tmp/linux-tools/prometheus_operator_setup.sh 
fi

if [[ $1 == "-i" ]] || [[ $2 == "-i" ]];then
	echo "Installating Ingress..."
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
EOF
fi

