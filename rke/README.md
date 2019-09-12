# 一、基础配置优化
```
groupadd docker
useradd -G docker docker
echo "123456" | passwd --stdin docker

sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config # 关闭selinux
systemctl stop firewalld.service && systemctl disable firewalld.service # 关闭防火墙
#echo 'LANG="en_US.UTF-8"' >> /etc/profile; source /etc/profile # 修改系统语言
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime # 修改时区（如果需要修改）

# 性能调优
cat >> /etc/sysctl.conf<<EOF
net.ipv4.ip_forward=1
net.bridge.bridge-nf-call-iptables=1
net.ipv4.neigh.default.gc_thresh1=4096
net.ipv4.neigh.default.gc_thresh2=6144
net.ipv4.neigh.default.gc_thresh3=8192
EOF
sysctl -p

cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
vm.swappiness=0
EOF
sysctl --system
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

3、创建k8s集群

```
rke up --config /tmp/cluster.yml

#为root用户配置kubectl访问k8s集群(因为这里指定了目录/tmp，所以kube_config_rancher-cluster.yml文件也在/tmp目录)
mkdir -p /root/.kube
cp /tmp/kube_config_rancher-cluster.yml /root/.kube/config
```

4、安装kubectl
```
curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl
chmod +x kubectl
mv kubectl /usr/local/bin/kubectl
kubectl version
```

参考资料：

http://www.acaiblog.cn/2019/03/15/RKE%E9%83%A8%E7%BD%B2rancher%E9%AB%98%E5%8F%AF%E7%94%A8%E9%9B%86%E7%BE%A4/
