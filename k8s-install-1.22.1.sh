#!/bin/bash
## Pre-Install { disable swap , set sysctl }
echo "net.bridge.bridge-nf-call-iptables  = 1 " > /etc/sysctl.d/99-kubernetes-cri.conf
echo "net.ipv4.ip_forward  = 1 " >> /etc/sysctl.d/99-kubernetes-cri.conf
echo "net.bridge.bridge-nf-call-ip6tables  = 1 " >> /etc/sysctl.d/99-kubernetes-cri.conf
sysctl --system

## Install CRI-O
echo "deb http://download.opensuse.org/repositories/devel:kubic:/libcontainers:/stable:/cri-o:/1.22/xUbuntu_20.04/ /" | tee -a /etc/apt/source.list.d/cri-0.list
curl -L http://download.opensuse.org/repositories/devel:kubic:/libcontainers:/stable:/cri-o:/1.22/xUbuntu_20.04/Release.key | apt-key add -
apt-get update && apt-get install -y cri-o cri-o-runc 

systemctl daemon-reload 
systemctl enable --now crio
systemctl status crio

## Prepare K* package
echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
apt-get update && apt-get install -y kubeadm=1.22.1-00 kubelet=1.22.1-00 kubectl=1.22.1-00
apt-mark hold kubeadm kubelet kubectl

# Pull image in background
kubeadm config images pull --kubernetes-version 1.22.1 >>/tmp/master-upgrade.log 2>&1 &

# Install master dependencies
#curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
#echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | tee /etc/apt/sources.list.d/kubernetes.list
#apt-get update -y >>/tmp/master-upgrade.log 2>&1
#apt-get install -y kubectl=1.22.1-00 kubeadm=1.22.1-00 kubelet=1.22.4-00 >>/tmp/master-upgrade.log 2>&1

# Install node dependencies
ssh node01 'apt-get update -y &&  apt-get install -y kubelet=1.22.1-00 kubeadm=1.22.1-00' >/tmp/node-upgrade.log 2>&1 &

# Install K8s
kubeadm init --kubernetes-version=1.22.1 --pod-network-cidr=100.64.0.0/16 >>/tmp/master-upgrade.log 2>&1

## Copy config
mkdir -p $HOME/.kube >>/tmp/master-upgrade.log 2>&1
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config >>/tmp/master-upgrade.log 2>&1
sudo chown $(id -u):$(id -g) $HOME/.kube/config >>/tmp/master-upgrade.log 2>&1

# join the node
NODE_JOIN_CMD=$(kubeadm token create --print-join-command)
NODE_JOIN_CMD_FULL="kubeadm reset -f;  ${NODE_JOIN_CMD} --ignore-preflight-errors=all"
ssh -tt node01 "${NODE_JOIN_CMD_FULL}"  >>/tmp/node-upgrade.log 2>&1 &

# Install CNI -- Calico
## kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')" >>/tmp/master-upgrade.log 2>&1
kubectl apply -f https://docs.projectcalico.org/mainfests/calico.yaml
touch /root/.kube/installed
