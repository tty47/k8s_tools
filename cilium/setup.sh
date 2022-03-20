#/bin/bash

# Source: 
# https://medium.com/@charled.breteche/kubernetes-security-control-pod-to-pod-communications-with-cilium-network-policies-d7275b2ed378

# --------------------------- 
kind create cluster --image kindest/node:v1.23.3 \
  --config - <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true        # do not install kindnet
  kubeProxyMode: none            # do not run kube-proxy
nodes:
- role: control-plane
- role: control-plane
- role: control-plane
- role: worker
- role: worker
- role: worker
EOF

# --------------------------- 
helm upgrade --install --namespace kube-system \
  --wait --timeout 15m --atomic \
  --repo https://helm.cilium.io cilium cilium \
  --values - <<EOF
kubeProxyReplacement: strict
k8sServiceHost: kind-external-load-balancer
k8sServicePort: 6443
policyEnforcementMode: always    # enforce network policies
hostServices:
  enabled: true
externalIPs:
  enabled: true
nodePort:
  enabled: true
hostPort:
  enabled: true
image:
  pullPolicy: IfNotPresent
ipam:
  mode: kubernetes
hubble:
  enabled: true
  relay:
    enabled: true
  ui:
    enabled: true
EOF

# --------------------------- 

# From the list above, core-dns pods are not getting Ready and local-path-provisioner is in Error.
# This is because those pods need to talk with the api server, but there is no network policy that allows such communications.
# Basically all pods running with hostNetwork will be fine, but those without will be in troubles if they need to communicate with another pod and don’t have a network policy that allows the traffic.

# Fix core-dns

# In order to resolve the core-dns pods issue, we will add a CiliumNetworkPolicy to allow core-dns pods to talk to the api server:

kubectl apply -f - <<EOF
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: core-dns
  namespace: kube-system
spec:
  endpointSelector:
    matchLabels:
      io.cilium.k8s.policy.serviceaccount: coredns
  egress:
  - toEntities:
    - kube-apiserver
EOF

# --------------------------- 

# Fix local-path-provisioner

# In the same spirit as core-dns pods, local-path-provisioner pods need to talk with the api server.
# We can apply almost the same policy to fix the issue:

kubectl apply -f - <<EOF
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: local-path-provisioner
  namespace: local-path-storage
spec:
  endpointSelector:
    matchLabels:
      io.cilium.k8s.policy.serviceaccount: local-path-provisioner-service-account
  egress:
  - toEntities:
    - kube-apiserver
EOF

# --------------------------- 
# Fix Hubble Relay

kubectl apply -f - <<EOF
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: hubble-relay
  namespace: kube-system
spec:
  endpointSelector:
    matchLabels:
      io.cilium.k8s.policy.serviceaccount: hubble-relay
  egress:
  - toEntities:
    - host
    - remote-node
EOF

# --------------------------- 
# We are able to communicate with Hubble UI but no namespaces are visible in the list.
# This makes sense as Hubble UI needs to talk to the api server to fetch the namespace list.
# Let’s allow Hubble UI pods to talk with the api server:

kubectl apply -f - <<EOF
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: hubble-ui
  namespace: kube-system
spec:
  endpointSelector:
    matchLabels:
      io.cilium.k8s.policy.serviceaccount: hubble-ui
  egress:
  - toEntities:
    - kube-apiserver
EOF

# --------------------------- 
# We need to allow communications between Hubble UI and Hubble Relay:

kubectl apply -f - <<EOF
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: hubble-ui
  namespace: kube-system
spec:
  endpointSelector:
    matchLabels:
      io.cilium.k8s.policy.serviceaccount: hubble-ui
  egress:
  - toEntities:
    - kube-apiserver
  - toEndpoints:
    - matchLabels:
        io.cilium.k8s.policy.serviceaccount: hubble-relay
---
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: hubble-relay
  namespace: kube-system
spec:
  endpointSelector:
    matchLabels:
      io.cilium.k8s.policy.serviceaccount: hubble-relay
  ingress:
  - fromEndpoints:
    - matchLabels:
        io.cilium.k8s.policy.serviceaccount: hubble-ui
  egress:
  - toEntities:
    - host
    - remote-node
EOF

# --------------------------- 
# To fix this error we need to add another policy to allow egress from Hubble UI pods to core-dns pods and allow ingress in core-dns pods from Hubble UI pods:

kubectl apply -f - <<EOF
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: hubble-ui
  namespace: kube-system
spec:
  endpointSelector:
    matchLabels:
      io.cilium.k8s.policy.serviceaccount: hubble-ui
  egress:
  - toEntities:
    - kube-apiserver
  - toEndpoints:
    - matchLabels:
        io.cilium.k8s.policy.serviceaccount: hubble-relay
    - matchLabels:
        io.cilium.k8s.policy.serviceaccount: coredns
---
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: core-dns
  namespace: kube-system
spec:
  endpointSelector:
    matchLabels:
      io.cilium.k8s.policy.serviceaccount: coredns
  ingress:
  - fromEndpoints:
    - matchLabels:
        io.cilium.k8s.policy.serviceaccount: hubble-ui
  egress:
  - toEntities:
    - kube-apiserver
EOF

# --------------------------- 
# One last fix
# Now Hubble UI works, we can observe that some communication is still blocked. The communication between core-dns pods and the world entity is not allowed.
# We can easily fix this by adding the world entity to the egress whitelist of core-dns pods:

kubectl apply -f - <<EOF
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: core-dns
  namespace: kube-system
spec:
  endpointSelector:
    matchLabels:
      io.cilium.k8s.policy.serviceaccount: coredns
  ingress:
  - fromEndpoints:
    - matchLabels:
        io.cilium.k8s.policy.serviceaccount: hubble-ui
  egress:
  - toEntities:
    - kube-apiserver
    - world
EOF

# --------------------------- 

