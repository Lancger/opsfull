# 一、初始化
```
cat > /etc/hosts << \EOF
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
192.168.56.11 linux-node1 linux-node1.example.com
192.168.56.12 linux-node2 linux-node2.example.com
192.168.56.13 linux-node3 linux-node3.example.com
EOF

systemctl stop firewalld
systemctl disable firewalld

setenforce 0
sed -i 's/SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config
sed -i 's/SELINUXTYPE=.*/SELINUXTYPE=disabled/g' /etc/selinux/config

swapoff -a
cat > /etc/sysctl.d/k8s.conf << \EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
vm.swappiness = 0
EOF
modprobe br_netfilter
sysctl -p /etc/sysctl.d/k8s.conf

cat > /etc/sysconfig/modules/ipvs.modules <<EOF
#!/bin/bash
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
modprobe -- nf_conntrack_ipv4
EOF

chmod 755 /etc/sysconfig/modules/ipvs.modules && bash /etc/sysconfig/modules/ipvs.modules && lsmod | grep -e ip_vs -e nf_conntrack_ipv4

yum install -y ipset ipvsadm

yum install chrony -y
systemctl enable chronyd
systemctl start chronyd
chronyc sources

yum install -y yum-utils \
  device-mapper-persistent-data \
  lvm2
  
yum-config-manager \
    --add-repo \
    https://download.docker.com/linux/centos/docker-ce.repo
    
#yum list docker-ce --showduplicates | sort -r

yum install -y docker-ce-19.03.1-3.el7
systemctl restart docker
systemctl enable docker
cat > /etc/docker/daemon.json << \EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "registry-mirrors" : [
    "https://ot2k4d59.mirror.aliyuncs.com/"
  ]
}
EOF

cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=http://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=http://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg
        http://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
kubeadm version
systemctl enable kubelet.service
```

# 二、初始化集群
```
#kubeadm config print init-defaults > kubeadm.yaml
#kubeadm init --config kubeadm.yaml

kubeadm init --kubernetes-version=v1.15.3 --pod-network-cidr=10.244.0.0/16  --apiserver-advertise-address=192.168.56.11 --apiserver-bind-port=6443 

#获取加入集群的指令
kubeadm token create --print-join-command

kubeadm join 192.168.56.11:6443 --token 5avfk1.fwui1smk5utcu7m9     --discovery-token-ca-cert-hash sha256:6730e91a516d8bf3e26d8f5eddd6409a224f8703b94f6ecde2b1fd7481bbbd25
```

# 三、Master操作
```
#将 master 节点上面的 $HOME/.kube/config 文件拷贝到 node 节点对应的文件中

mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config

scp $HOME/.kube/config root@linux-node2:$HOME/.kube/config
scp $HOME/.kube/config root@linux-node3:$HOME/.kube/config
scp $HOME/.kube/config root@linux-node4:$HOME/.kube/config
```

# 四、Node操作
```
#node节点操作
mkdir -p $HOME/.kube
sudo chown $(id -u):$(id -g) $HOME/.kube/config

#加入集群
kubeadm join 192.168.56.11:6443 --token 5avfk1.fwui1smk5utcu7m9     --discovery-token-ca-cert-hash sha256:6730e91a516d8bf3e26d8f5eddd6409a224f8703b94f6ecde2b1fd7481bbbd25
```

# 五、集群操作
```
iptables -I RH-Firewall-1-INPUT -s 10.96.0.0/12 -j ACCEPT
service iptables save

kubectl get pods -n kube-system         

kubectl describe pod/calico-kube-controllers-65b8787765-mhhw8 -n kube-system

#批量重启docker
docker restart `docker ps -a -q` 

root># kubectl get nodes
NAME                      STATUS     ROLES    AGE     VERSION
linux-node1.example.com   NotReady   master   11m     v1.15.3
linux-node2.example.com   NotReady   <none>   5m9s    v1.15.3
linux-node3.example.com   NotReady   <none>   4m58s   v1.15.3

可以看到是 NotReady 状态，这是因为还没有安装网络插件，接下来安装网络插件，可以在文档 https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/ 中选择我们自己的网络插件，这里我们安装 calio:
```

# 五、master上部署flannel插件
```
wget https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

kubectl apply -f kube.yml
```

参考文档：

https://www.qikqiak.com/post/use-kubeadm-install-kubernetes-1.15.3/ 

https://www.jianshu.com/p/351acb6811fd  
