# 一、清理资源
```
systemctl stop kubelet.service
systemctl stop kubelet
systemctl stop docker

kubeadm reset
#yum remove -y kubelet kubeadm kubectl --disableexcludes=kubernetes

rm -rf /etc/kubernetes/
rm -rf /root/.kube/
rm -rf $HOME/.kube/
rm -rf /var/lib/etcd/
rm -rf /var/lib/cni/
rm -rf /var/lib/kubelet/
rm -rf /etc/cni/
rm -rf /opt/cni/

ifconfig cni0 down
ifconfig flannel.1 down
ifconfig docker0 down
ip link delete cni0
ip link delete flannel.1

#docker rmi -f $(docker images -q)
#docker rm -f `docker ps -a -q`

#yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
kubeadm version
systemctl restart kubelet.service
systemctl enable kubelet.service
```

# 二、重新初始化
```
swapoff -a
modprobe br_netfilter
sysctl -p /etc/sysctl.d/k8s.conf
chmod 755 /etc/sysconfig/modules/ipvs.modules && bash /etc/sysconfig/modules/ipvs.modules && lsmod | grep -e ip_vs -e nf_conntrack_ipv4

kubeadm config images list |sed -e 's/^/docker pull /g' -e 's#k8s.gcr.io#registry.cn-hangzhou.aliyuncs.com/google_containers#g' |sh -x
docker images |grep google_containers |awk '{print "docker tag ",$1":"$2,$1":"$2}' |sed -e 's#registry.cn-hangzhou.aliyuncs.com/google_containers#k8s.gcr.io#2' |sh -x
docker images |grep google_containers |awk '{print "docker rmi ", $1":"$2}' |sh -x
docker pull coredns/coredns:1.3.1
docker tag coredns/coredns:1.3.1 k8s.gcr.io/coredns:1.3.1
docker rmi coredns/coredns:1.3.1

kubeadm init --kubernetes-version=v1.15.3 --pod-network-cidr=10.244.0.0/16  --apiserver-advertise-address=192.168.56.11 --apiserver-bind-port=6443

#获取加入集群的指令
kubeadm token create --print-join-command
```

# 三、Node操作
```
mkdir -p $HOME/.kube
```

# 四、Master操作
```
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

scp $HOME/.kube/config root@linux-node2:$HOME/.kube/config
scp $HOME/.kube/config root@linux-node3:$HOME/.kube/config
scp $HOME/.kube/config root@linux-node4:$HOME/.kube/config
```

# 五、Master和Node节点
```
chown $(id -u):$(id -g) $HOME/.kube/config

```


参考资料：

https://blog.51cto.com/wutengfei/2121202  kubernetes中网络报错问题
