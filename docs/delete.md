```
#master
systemctl restart kube-scheduler
systemctl restart kube-controller-manager
systemctl restart kube-apiserver
systemctl restart flannel
systemctl restart etcd
systemctl restart docker


systemctl stop kube-scheduler
systemctl stop kube-controller-manager
systemctl stop kube-apiserver
systemctl stop flannel
systemctl stop etcd
systemctl stop docker

#node
systemctl restart kubelet
systemctl restart kube-proxy
systemctl restart flannel
systemctl restart etcd
systemctl restart docker


systemctl stop kubelet
systemctl stop kube-proxy
systemctl stop flannel
systemctl stop etcd
systemctl stop docker

```

```
# 清理k8s集群
rm -rf /var/lib/etcd/
rm -rf /var/lib/docker
rm -rf /opt/containerd
rm -rf /opt/kubernetes
rm -rf /var/lib/kubelet
rm -rf /var/lib/chrony
rm -rf /var/lib/kube-proxy


systemctl disable kube-scheduler
systemctl disable kube-controller-manager
systemctl disable kube-apiserver
systemctl disable flannel
systemctl disable etcd
systemctl disable docker

systemctl disable kubelet
systemctl disable kube-proxy
systemctl disable flannel
systemctl disable etcd
systemctl disable docker

```
