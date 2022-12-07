#!/bin/zsh
# ============================================================================
#Colours
greenColour="\e[0;32m\033[1m"
endColour="\033[0m\e[0m"
blueColour="\e[0;34m\033[1m"
grayColour="\e[0;37m\033[1m"

KUBERNETES_VERSION="v1.25.3"
KCP_NODES="3"
KWM_NODES="3"
CILIUM_VERSION="1.12.4"

# ============================================================================
clear
set -o errexit

# ============================================================================
# Default path to the kubeconfig
export KUBECONFIG=~/.kube/config
# The list of service CIDR, default ["10.128.0.0/12"]
export SERVICE_CIDR=["10.96.0.0/12"]
# The list of pod CIDR, default ["192.168.0.0/16"]
export POD_CIDR=["192.168.0.0/16"]
# The service domain, default "cluster.local"
export SERVICE_DOMAIN="k8s.test"
#It is also possible but not recommended to disable the per-default
#enabled Pod Security Standard:
export ENABLE_POD_SECURITY_STANDARD="false"

# ============================================================================
# line reuse line code
function line(){
  echo -e "${grayColour}============================================================= > ${endColour}"
}

# ============================================================================
line 
echo "Initialize the management cluster..."
# Enable the experimental Cluster topology feature.
export CLUSTER_TOPOLOGY=true
# Initialize the management cluster
IS_INIT=$(kubectl get po -n cert-manager -o name -l app=cert-manager)
if [[ -z "${IS_INIT}" ]]; then
  echo "Setting up Management cluster..."
  clusterctl init --infrastructure docker
else
  line
  echo "Management Cluster components already installed"
fi
line

# ============================================================================
echo -e "${blueColour}What's the name of your cluster?${endColour}"
read clusterName
if [[ -z "${clusterName}" ]]; then
  echo "ERROR: You have to specify the cluster name.."
  exit 1
fi
echo -e "Cluster name is: ${greenColour}[${clusterName}]${endColour}"
echo -e "Cluster version is: ${greenColour}[${KUBERNETES_VERSION}]${endColour}"
line

echo "How many Control Plane Nodes do you want?"
read KCP_NODES
line
echo "How many Worker Machine Nodes do you want?"
read KWM_NODES
line

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
rm -f capi-${clusterName}.yaml-e

line
echo "Check the file: [./capi-${clusterName}.yaml]"

line
echo "Applying the manifest..."
kubectl apply -f ./capi-${clusterName}.yaml

echo "Check the clusters..."
kubectl get cluster
sleep 10

#https://cluster-api.sigs.k8s.io/clusterctl/developers.html#additional-notes-for-the-docker-provider
line
echo "Describe the cluster [${clusterName}]"
clusterctl describe cluster ${clusterName}

line
echo -e "${blueColour}Get the ControlPlane [${clusterName}] ${endColour}"
kubectl get kubeadmcontrolplane

line
echo -e "${blueColour}Get the KubeConfig [${clusterName}] ${endColour}"
clusterctl get kubeconfig  ${clusterName} > ./capi-${clusterName}.kubeconfig

# source: https://cluster-api.sigs.k8s.io/clusterctl/developers.html#fix-kubeconfig-when-using-docker-desktop-and-clusterctl
sed -i -e "s/server:.*/server: https:\/\/$(docker port ${clusterName}-lb 6443/tcp | sed "s/0.0.0.0/127.0.0.1/")/g" ./capi-${clusterName}.kubeconfig
rm -f capi-${clusterName}.kubeconfig-e

line
echo -e "Check the nodes using the new kubeconfig ${blueColour}[./capi-${clusterName}.kubeconfig]${endColour}"
kubectl get no --kubeconfig=./capi-${clusterName}.kubeconfig
export KUBECONFIG=./capi-${clusterName}.kubeconfig

# ============================================================================
line
echo "Do you want to install Cilium as CNI?, y/n"
read installCilium 
if [[ -z "${installCilium}" ]]; then
  echo "ERROR: You must set the value to install CNI..."
  exit 1
fi
if [[ "${installCilium}" == "y" ]];then
  echo "Yes, install it"
  helm repo add cilium https://helm.cilium.io/
  helm install cilium cilium/cilium \
    --version ${CILIUM_VERSION} \
    --namespace kube-system
else 
  echo "NO thanks!"
fi

line
echo "Checking nodes & pods.."
kubectl get no
kubectl get po -A
line
