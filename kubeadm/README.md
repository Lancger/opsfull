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

yum install -y docker-ce-19.03.2-3.el7
systemctl start docker
systemctl enable docker
cat > /etc/docker/daemon.json << \EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "registry-mirrors" : [
    "https://ot2k4d59.mirror.aliyuncs.com/"
  ]
}
EOF
systemctl daemon-reload
systemctl restart docker

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
systemctl daemon-reload
systemctl restart kubelet.service
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
#批量重启docker
docker restart `docker ps -a -q` 

root># kubectl get nodes
NAME                      STATUS     ROLES    AGE     VERSION
linux-node1.example.com   NotReady   master   11m     v1.15.3
linux-node2.example.com   NotReady   <none>   5m9s    v1.15.3
linux-node3.example.com   NotReady   <none>   4m58s   v1.15.3

可以看到是 NotReady 状态，这是因为还没有安装网络插件，接下来安装网络插件，可以在文档 https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/ 中选择我们自己的网络插件，这里我们安装 flannel:

iptables -I RH-Firewall-1-INPUT -s 10.96.0.0/12 -j ACCEPT
service iptables save

root># kubectl get pods -n kube-system
NAME                                              READY   STATUS    RESTARTS   AGE
coredns-5c98db65d4-mk254                          1/1     Running   0          14m
coredns-5c98db65d4-ntz98                          1/1     Running   0          14m
etcd-linux-node1.example.com                      1/1     Running   0          13m
kube-apiserver-linux-node1.example.com            1/1     Running   0          13m
kube-controller-manager-linux-node1.example.com   1/1     Running   0          13m
kube-flannel-ds-amd64-6kx7m                       1/1     Running   0          11m
kube-flannel-ds-amd64-cqfnb                       1/1     Running   0          11m
kube-flannel-ds-amd64-thxx2                       1/1     Running   0          11m
kube-proxy-gdtjg                                  1/1     Running   0          12m
kube-proxy-lcscl                                  1/1     Running   0          14m
kube-proxy-sb7d8                                  1/1     Running   0          12m
kube-scheduler-linux-node1.example.com            1/1     Running   0          13m
kubernetes-dashboard-fcfb4cbc-dqbq9               1/1     Running   0          4m43s

kubectl describe pod/coredns-5c98db65d4-mk254 -n kube-system
```

# 五、master上部署flannel插件
```
wget https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

kubectl apply -f kube-flannel.yml
```

# 六、安装 Dashboard

1、下载yaml文件
```
wget https://raw.githubusercontent.com/kubernetes/dashboard/v1.10.1/src/deploy/recommended/kubernetes-dashboard.yaml

vim kubernetes-dashboard.yaml
# 修改镜像名称
......
containers:
- args:
  - --auto-generate-certificates
  image: gcr.azk8s.cn/google_containers/kubernetes-dashboard-amd64:v1.10.1
  imagePullPolicy: IfNotPresent
  
......
# 修改Service为NodePort类型
......
selector:
  k8s-app: kubernetes-dashboard
type: NodePort
```

2、创建dashboard
```
kubectl apply -f kubernetes-dashboard.yaml

root># kubectl get pods -n kube-system -l k8s-app=kubernetes-dashboard
NAME                                  READY   STATUS    RESTARTS   AGE
kubernetes-dashboard-fcfb4cbc-dqbq9   1/1     Running   0          8m5s

root># kubectl get svc -n kube-system -l k8s-app=kubernetes-dashboard
NAME                   TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)         AGE
kubernetes-dashboard   NodePort   10.107.51.169   <none>        443:31513/TCP   8m25s
```
然后可以通过上面的 https://NodeIP:31513 端口去访问 Dashboard，要记住使用 https，Chrome不生效可以使用Firefox测试：

3、然后创建一个具有全局所有权限的用户来登录Dashboard：(admin.yaml)
```
cat > admin.yaml << \EOF
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: admin
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: ServiceAccount
  name: admin
  namespace: kube-system

---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin
  namespace: kube-system
  labels:
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
EOF

kubectl apply -f admin.yaml

kubectl get secret -n kube-system|grep admin-token

#获取token
kubectl get secret admin-token-d5jsg -o jsonpath={.data.token} -n kube-system |base64 -d
```

然后用上面的base64解码后的字符串作为token登录Dashboard即可： k8s dashboard

最终我们就完成了使用 kubeadm 搭建 v1.15.3 版本的 kubernetes 集群、coredns、ipvs、flannel。 

参考文档：

https://www.qikqiak.com/post/use-kubeadm-install-kubernetes-1.15.3/ 

https://www.jianshu.com/p/351acb6811fd  
