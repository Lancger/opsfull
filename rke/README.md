# 一、基础配置优化
```
chattr -i /etc/passwd* && chattr -i /etc/group* && chattr -i /etc/shadow* && chattr -i /etc/gshadow*
groupadd docker
useradd -g docker docker
echo "1Qaz2Wsx3Edc" | passwd --stdin docker
usermod docker -G docker  #注意这里需要将数组改为docker属组，不然会报错

setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config # 关闭selinux
systemctl daemon-reload
systemctl stop firewalld.service && systemctl disable firewalld.service # 关闭防火墙
#echo 'LANG="en_US.UTF-8"' >> /etc/profile; source /etc/profile # 修改系统语言
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime # 修改时区（如果需要修改）

# 性能调优
cat >> /etc/sysctl.conf<<EOF
net.bridge.bridge-nf-call-iptables=1
net.ipv4.neigh.default.gc_thresh1=4096
net.ipv4.neigh.default.gc_thresh2=6144
net.ipv4.neigh.default.gc_thresh3=8192
EOF
sysctl -p

cat <<EOF >  /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward=1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
vm.swappiness=0
EOF
sysctl --system

#docker用户免密登录
mkdir -p /home/docker/.ssh/
chmod 700 /home/docker/.ssh/
echo 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7bRm20od1b3rzW3ZPLB5NZn3jQesvfiz2p0WlfcYJrFHfF5Ap0ubIBUSQpVNLn94u8ABGBLboZL8Pjo+rXQPkIcObJxoKS8gz6ZOxcxJhl11JKxTz7s49nNYaNDIwB13KaNpvBEHVoW3frUnP+RnIKIIDsr1QCr9t64D9TE99mbNkEvDXr021UQi12Bf4KP/8gfYK3hDMRuX634/K8yu7+IaO1vEPNT8HDo9XGcvrOD1QGV+is8mrU53Xa2qTsto7AOb2J8M6n1mSZxgNz2oGc6ZDuN1iMBfHm4O/s5VEgbttzB2PtI0meKeaLt8VaqwTth631EN1ryjRYUuav7bf docker@k8s-master-01' > /home/docker/.ssh/authorized_keys
chmod 400 /home/docker/.ssh/authorized_keys
```

## 二、基础环境准备

```
mkdir -p /etc/yum.repos.d_bak/
mv /etc/yum.repos.d/* /etc/yum.repos.d_bak/
curl http://mirrors.aliyun.com/repo/Centos-7.repo >/etc/yum.repos.d/Centos-7.repo
curl http://mirrors.aliyun.com/repo/epel-7.repo >/etc/yum.repos.d/epel-7.repo
sed -i '/aliyuncs/d' /etc/yum.repos.d/Centos-7.repo
yum clean all && yum makecache fast

yum -y install yum-utils
yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
yum install -y device-mapper-persistent-data lvm2

yum install docker-ce -y

#从docker1.13版本开始，docker会自动设置iptables的FORWARD默认策略为DROP，所以需要修改docker的启动配置文件/usr/lib/systemd/system/docker.service

cat > /usr/lib/systemd/system/docker.service << \EOF
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
BindsTo=containerd.service
After=network-online.target firewalld.service containerd.service
Wants=network-online.target
Requires=docker.socket
[Service]
Type=notify
ExecStart=/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock
ExecStartPost=/usr/sbin/iptables -P FORWARD ACCEPT
ExecReload=/bin/kill -s HUP \$MAINPID
TimeoutSec=0
RestartSec=2
Restart=always
StartLimitBurst=3
StartLimitInterval=60s
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
Delegate=yes
KillMode=process
[Install]
WantedBy=multi-user.target
EOF

#设置加速器
curl -sSL https://get.daocloud.io/daotools/set_mirror.sh | sh -s http://41935bf4.m.daocloud.io
#这个脚本在centos 7上有个bug,脚本会改变docker的配置文件/etc/docker/daemon.json但修改的时候多了一个逗号,导致docker无法启动

#或者直接执行这个指令
tee /etc/docker/daemon.json <<-'EOF'
{
"registry-mirrors": ["https://1z45x7d0.mirror.aliyuncs.com"],
"insecure-registries": ["192.168.56.11:5000"],
"storage-driver": "overlay2",
"log-driver": "json-file",
"log-opts": {
    "max-size": "100m",
    "max-file": "3"
    }
}
EOF
systemctl daemon-reload
systemctl restart docker

#查看加速器是否生效
root># docker info
 Registry Mirrors:
  https://1z45x7d0.mirror.aliyuncs.com/   --发现参数已经生效
 Live Restore Enabled: false
```

## 三、RKE安装

使用RKE安装，需要先安装好docker和设置好root和普通用户的免key登录

1、下载RKE
```
#可以从https://github.com/rancher/rke/releases下载安装包,本文使用版本v0.3.0.下载完后将安装包上传至任意节点.

wget https://github.com/rancher/rke/releases/download/v0.2.8/rke_linux-amd64
chmod 777 rke_linux-amd64
mv rke_linux-amd64 /usr/local/bin/rke
```

2、创建集群配置文件
```
cat >/tmp/cluster.yml <<EOF
nodes:
    - address: 192.168.56.11
      user: docker
      role:
        - controlplane
        - etcd
        - worker
    - address: 192.168.56.12
      user: docker
      role:
        - controlplane
        - etcd
        - worker
    - address: 192.168.56.13
      user: docker
      role:
        - controlplane
        - etcd
        - worker
cluster_name: paas_cluster
EOF

chmod 777 /tmp/cluster.yml
```

3、创建k8s集群(注意这里需要切换为普通用户操作)

```
su - docker 
rke up --config /tmp/cluster.yml

#为root用户配置kubectl访问k8s集群(因为这里指定了目录/tmp，所以kube_config_cluster.yml文件也在/tmp目录)
su - root
mkdir -p /root/.kube
cp /tmp/kube_config_cluster.yml /root/.kube/config

#其他master02 master03节点也需要同步该文件
ssh root@k8s-master-02 mkdir -p /root/.kube
scp /root/.kube/config root@k8s-master-02:/root/.kube/config

ssh root@k8s-master-03 mkdir -p /root/.kube
scp /root/.kube/config root@k8s-master-03:/root/.kube/config

#查看日志
docker logs kube-proxy
```

4、安装kubectl
```
curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl
chmod +x kubectl
mv kubectl /usr/local/bin/kubectl
kubectl version
```

5、检查k8s集群pod状态
```
[root@master01 ~]# kubectl get pods --all-namespaces
NAMESPACE       NAME                                      READY   STATUS      RESTARTS   AGE
ingress-nginx   default-http-backend-7f8fbb85db-rxs9r     1/1     Running     0          106s
ingress-nginx   nginx-ingress-controller-9vhbj            1/1     Running     0          10m
ingress-nginx   nginx-ingress-controller-lhvk4            1/1     Running     0          10m
kube-system     canal-9lhlr                               2/2     Running     0          10m
kube-system     canal-xxz5p                               2/2     Running     0          10m
kube-system     kube-dns-5fd74c7488-54dgp                 3/3     Running     0          10m
kube-system     kube-dns-autoscaler-c89df977f-fb42z       1/1     Running     0          10m
kube-system     metrics-server-7fbd549b78-8hftl           1/1     Running     0          10m
kube-system     rke-ingress-controller-deploy-job-8c9c2   0/1     Completed   0          10m
kube-system     rke-kubedns-addon-deploy-job-lp5tc        0/1     Completed   0          10m
kube-system     rke-metrics-addon-deploy-job-j585d        0/1     Completed   0          10m
kube-system     rke-network-plugin-deploy-job-xssrc       0/1     Completed   0          10m

pod的状态只有以上两种状态为正常状态，若有其他状态则需要查看pod日志

kubectl describe pod pod-xxx -n namespace
```

6、指令补全
```
yum install bash-completion -y

source <(kubectl completion bash)
echo "source <(kubectl completion bash)" >> ~/.bashrc
```

# 四、helm将rancher部署在k8s集群

1、安装并配置helm客户端
```
#使用官方提供的脚本一键安装
curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh


#手动下载安装
#下载 Helm 
wget https://storage.googleapis.com/kubernetes-helm/helm-v2.9.1-linux-amd64.tar.gz
#解压 Helm
tar -zxvf helm-v2.9.1-linux-amd64.tar.gz
#复制客户端执行文件到 bin 目录下
cp linux-amd64/helm /usr/local/bin/
```

2、配置helm客户端具有访问k8s集群的权限
```
kubectl -n kube-system create serviceaccount tiller
kubectl create clusterrolebinding tiller --clusterrole cluster-admin --serviceaccount=kube-system:tiller

```
3、将helm server（titler）部署到k8s集群
```
helm init --service-account tiller --tiller-image hongxiaolu/tiller:v2.12.3 --stable-repo-url https://kubernetes.oss-cn-hangzhou.aliyuncs.com/charts
```
4、为helm客户端配置chart仓库
```
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
```
5、检查rancher chart仓库可用
```
helm search rancher
```
```
安装证书管理器
helm install stable/cert-manager \
  --name cert-manager \
  --namespace kube-system
  
 kubectl get pods --all-namespaces|grep cert-manager
  
  
 helm install rancher-stable/rancher \
  --name rancher \
  --namespace cattle-system \
  --set hostname=acai.rancher.com
  
```

参考资料：

http://www.acaiblog.cn/2019/03/15/RKE%E9%83%A8%E7%BD%B2rancher%E9%AB%98%E5%8F%AF%E7%94%A8%E9%9B%86%E7%BE%A4/

https://blog.csdn.net/login_sonata/article/details/93847888
