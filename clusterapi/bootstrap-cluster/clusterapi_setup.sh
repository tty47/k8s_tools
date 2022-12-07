#!/bin/sh
# Source: https://kind.sigs.k8s.io/docs/user/local-registry/
clear

KUBERNETES_VERSION="v1.25.3"
KCP_NODES="3"
KWM_NODES="3"

set -o errexit

export KUBECONFIG=~/.kube/config

echo "========================================= >"
echo "Initialize the management cluster..."
# Enable the experimental Cluster topology feature.
export CLUSTER_TOPOLOGY=true
# Initialize the management cluster
clusterctl init --infrastructure docker
echo "========================================= >"

# The list of service CIDR, default ["10.128.0.0/12"]
export SERVICE_CIDR=["10.96.0.0/12"]
# The list of pod CIDR, default ["192.168.0.0/16"]
export POD_CIDR=["192.168.0.0/16"]
# The service domain, default "cluster.local"
export SERVICE_DOMAIN="k8s.test"
#It is also possible but not recommended to disable the per-default
#enabled Pod Security Standard:
export ENABLE_POD_SECURITY_STANDARD="false"

echo "What's the name of your cluster? \n"
read clusterName
echo "Cluster name is: [${clusterName}]"
echo "Cluster version is: [${KUBERNETES_VERSION}]"
echo "========================================= >"

echo "How many Control Plane Nodes do you want? \n"
read KCP_NODES
echo "How many Worker Machine Nodes do you want? \n"
read KWM_NODES

if [[ -z "${KCP_NODES}" ]] || [[ -z "${KCP_NODES}" ]]; then
  echo "ERROR: You must set the values for the Control Plane nodes and Worker
  Machine nodes..."
  exit 1
fi

#clusterctl generate cluster ${clusterName} --kubernetes-version ${KUBERNETES_VERSION} | kubectl apply -f -
echo "Generating Cluster manifest..."
clusterctl generate cluster ${clusterName} --flavor development \
  --kubernetes-version ${KUBERNETES_VERSION} \
  --control-plane-machine-count=${KCP_NODES} \
  --worker-machine-count=${KWM_NODES} \
  --infrastructure docker \
  > capi-${clusterName}.yaml

sed -i -e "s/quick-start/${clusterName}/g" capi-${clusterName}.yaml
rm capi-${clusterName}.yaml-e

echo "========================================= >"
echo "Check the file: [./capi-${clusterName}.yaml]"

echo "========================================= >"
echo "Applying the manifest..."
kubectl apply -f ./capi-${clusterName}.yaml

echo "Check the clusters..."
kubectl get cluster
sleep 10

#https://cluster-api.sigs.k8s.io/clusterctl/developers.html#additional-notes-for-the-docker-provider
echo "========================================= >"
echo "Describe the cluster [${clusterName}]"
clusterctl describe cluster ${clusterName}

echo "========================================= >"
echo "Get the controlPlane [${clusterName}]"
kubectl get kubeadmcontrolplane

echo "========================================= >"
echo "Get the kubeconfig [${clusterName}]"
clusterctl get kubeconfig  ${clusterName} > ./capi-${clusterName}.kubeconfig

# source: https://cluster-api.sigs.k8s.io/clusterctl/developers.html#fix-kubeconfig-when-using-docker-desktop-and-clusterctl
sed -i -e "s/server:.*/server: https:\/\/$(docker port ${clusterName}-lb 6443/tcp | sed "s/0.0.0.0/127.0.0.1/")/g" ./capi-${clusterName}.kubeconfig
rm capi-${clusterName}.kubeconfig-e

echo "========================================= >"
echo "Check the nodes using the new kubeconfig [./capi-${clusterName}.kubeconfig]"
kubectl get no --kubeconfig=./capi-${clusterName}.kubeconfig
export KUBECONFIG=./capi-${clusterName}.kubeconfig

echo "========================================= >"
echo "Do you want to install Cilium as CNI?, y/n \n"
read installCilium 

if [ "$installCilium" == "y" ];then
  echo "Yes, install it"
  helm repo add cilium https://helm.cilium.io/
  helm install cilium cilium/cilium --version 1.12.4 \
  --namespace kube-system
else 
  echo "NO thanks!"
fi

echo "========================================= >"
echo "Checking nodes & pods.."
kubectl get no
kubectl get po -A
echo "========================================= >"
