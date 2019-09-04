# 一、清理资源
```
systemctl stop kubelet.service
yum remove -y kubelet kubeadm kubectl --disableexcludes=kubernetes

rm -rf /etc/kubernetes/
rm -rf /root/.kube/
rm -rf /var/lib/etcd/
rm -rf /var/lib/kubelet/

docker rmi -f $(docker images -q)
docker rm -f `docker ps -a -q`

yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
kubeadm version
systemctl restart kubelet.service
systemctl enable kubelet.service
```

# 二、重新初始化
```
kubeadm init --config kubeadm.yaml
```
