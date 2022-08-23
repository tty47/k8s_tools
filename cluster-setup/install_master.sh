#!/bin/bash

# Source: http://kubernetes.io/docs/getting-started-guides/kubeadm

set -e

export KUBE_VERSION=1.24.4

sudo apt-get update
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg gnupg2 gnupg1

### disable linux swap and remove any existing swap partitions
swapoff -a
sed -i '/\sswap\s/ s/^\(.*\)$/#\1/g' /etc/fstab

echo "Installing containerD..."
echo "- - - - - -- - - - - - - - - - - - - - - - - - - - - - - - - -"
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
echo "deb [arch=amd64] https://download.docker.com/linux/debian buster stable" |sudo tee /etc/apt/sources.list.d/docker.list
sudo apt update
sudo apt install -y containerd
echo "- - - - - -- - - - - - - - - - - - - - - - - - - - - - - - - -"

echo "- - - - - -- - - - - - - - - - - - - - - - - - - - - - - - - -"
sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list

echo "- - - - - -- - - - - - - - - - - - - - - - - - - - - - - - - -"
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
echo "- - - - - -- - - - - - - - - - - - - - - - - - - - - - - - - -"


echo "- - - - - -- - - - - - - - - - - - - - - - - - - - - - - - - -"
echo "Cleaning files..."
if [[ -f "/etc/kubernetes/manifests/kube-controller-manager.yaml" ]];then
  rm /etc/kubernetes/manifests/kube-controller-manager.yaml
fi
if [[ -f "/etc/kubernetes/manifests/kube-scheduler.yaml" ]];then
  rm /etc/kubernetes/manifests/kube-scheduler.yaml
fi
if [[ -f "/etc/kubernetes/manifests/kube-apiserver.yaml" ]];then
  rm /etc/kubernetes/manifests/kube-apiserver.yaml
fi
echo "- - - - - -- - - - - - - - - - - - - - - - - - - - - - - - - -"

echo "- - - - - -- - - - - - - - - - - - - - - - - - - - - - - - - -"
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sudo sysctl --system
sudo mkdir -p /etc/containerd
echo "- - - - - -- - - - - - - - - - - - - - - - - - - - - - - - - -"

echo "- - - - - -- - - - - - - - - - - - - - - - - - - - - - - - - -"
### containerd config
cat > /etc/containerd/config.toml <<EOF
disabled_plugins = []
imports = []
oom_score = 0
plugin_dir = ""
required_plugins = []
root = "/var/lib/containerd"
state = "/run/containerd"
version = 2

[plugins]

  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
      base_runtime_spec = ""
      container_annotations = []
      pod_annotations = []
      privileged_without_host_devices = false
      runtime_engine = ""
      runtime_root = ""
      runtime_type = "io.containerd.runc.v2"

      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
        BinaryName = ""
        CriuImagePath = ""
        CriuPath = ""
        CriuWorkPath = ""
        IoGid = 0
        IoUid = 0
        NoNewKeyring = false
        NoPivotRoot = false
        Root = ""
        ShimCgroup = ""
        SystemdCgroup = true
EOF
echo "- - - - - -- - - - - - - - - - - - - - - - - - - - - - - - - -"

echo "- - - - - -- - - - - - - - - - - - - - - - - - - - - - - - - -"
### crictl uses containerd as default
{
cat <<EOF | sudo tee /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
EOF
}
echo "- - - - - -- - - - - - - - - - - - - - - - - - - - - - - - - -"

echo "- - - - - -- - - - - - - - - - - - - - - - - - - - - - - - - -"
### kubelet should use containerd
{
cat <<EOF | sudo tee /etc/default/kubelet
KUBELET_EXTRA_ARGS="--container-runtime remote --container-runtime-endpoint unix:///run/containerd/containerd.sock"
EOF
}
echo "- - - - - -- - - - - - - - - - - - - - - - - - - - - - - - - -"

echo "- - - - - -- - - - - - - - - - - - - - - - - - - - - - - - - -"
### start services
systemctl daemon-reload
systemctl enable containerd
systemctl restart containerd
systemctl enable kubelet && systemctl start kubelet
echo "- - - - - -- - - - - - - - - - - - - - - - - - - - - - - - - -"

# In case the starts fail
#kubeadm reset || true

if [[ -f "/root/.kube/config" ]];then
   rm /root/.kube/config
fi

echo "- - - - - -- - - - - - - - - - - - - - - - - - - - - - - - - -"
### init k8s
kubeadm init --kubernetes-version=${KUBE_VERSION} --ignore-preflight-errors=NumCPU --skip-token-print --pod-network-cidr 192.168.0.0/16

echo "- - - - - -- - - - - - - - - - - - - - - - - - - - - - - - - -"
mkdir -p ~/.kube
sudo cp -i /etc/kubernetes/admin.conf ~/.kube/config
echo "- - - - - -- - - - - - - - - - - - - - - - - - - - - - - - - -"

echo "- - - - - -- - - - - - - - - - - - - - - - - - - - - - - - - -"
### CNI
kubectl apply -f https://raw.githubusercontent.com/killer-sh/cks-course-environment/master/cluster-setup/calico.yaml
echo "- - - - - -- - - - - - - - - - - - - - - - - - - - - - - - - -"

echo "- - - - - -- - - - - - - - - - - - - - - - - - - - - - - - - -"
# etcdctl
ETCDCTL_VERSION=v3.5.1
ETCDCTL_VERSION_FULL=etcd-${ETCDCTL_VERSION}-linux-amd64
wget https://github.com/etcd-io/etcd/releases/download/${ETCDCTL_VERSION}/${ETCDCTL_VERSION_FULL}.tar.gz
tar xzf ${ETCDCTL_VERSION_FULL}.tar.gz
mv ${ETCDCTL_VERSION_FULL}/etcdctl /usr/bin/
rm -rf ${ETCDCTL_VERSION_FULL} ${ETCDCTL_VERSION_FULL}.tar.gz
echo "- - - - - -- - - - - - - - - - - - - - - - - - - - - - - - - -"


echo "- - - - - -- - - - - - - - - - - - - - - - - - - - - - - - - -"
echo
echo "### COMMAND TO ADD A WORKER NODE ###"
kubeadm token create --print-join-command --ttl 0
echo "- - - - - -- - - - - - - - - - - - - - - - - - - - - - - - - -"
