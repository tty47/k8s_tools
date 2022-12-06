#!/bin/sh
# Source: https://kind.sigs.k8s.io/docs/user/local-registry/
clear

KUBERNETES_VERSION="v1.25.0"

set -o errexit

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

#clusterctl generate cluster ${clusterName} --kubernetes-version ${KUBERNETES_VERSION} | kubectl apply -f -

echo "Generating Cluster manifest..."
clusterctl generate cluster ${clusterName} --flavor development \
  --kubernetes-version ${KUBERNETES_VERSION} \
  --control-plane-machine-count=3 \
  --worker-machine-count=3 \
  > capi-${clusterName}.yaml

echo "Check the file: [./capi-${clusterName}.yaml]"
echo "========================================= >"
