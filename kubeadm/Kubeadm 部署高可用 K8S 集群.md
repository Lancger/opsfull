# 环境介绍：
```bash
CentOS： 7.6
Docker： 18.06.1-ce
Kubernetes： 1.13.4
Kuberadm： 1.13.4
Kuberlet： 1.13.4
Kuberctl： 1.13.4
```  
# 部署介绍：

&#8195;创建高可用首先先有一个 Master 节点，然后再让其他服务器加入组成三个 Master 节点高可用，然后再将工作节点 Node 加入。下面将描述每个节点要执行的步骤：
```bash
Master01： 二、三、四、五、六、七、八、九、十一
Master02、Master03： 二、三、五、六、四、九
node01、node02： 二、五、六、九
```
# 集群架构：

  ![kubeadm高可用架构图](https://github.com/Lancger/opsfull/blob/master/images/kubeadm-ha.jpg)
 
## 一、kuberadm 简介

### 1、Kuberadm 作用

&#8195;Kubeadm 是一个工具，它提供了 kubeadm init 以及 kubeadm join 这两个命令作为快速创建 kubernetes 集群的最佳实践。

&#8195;kubeadm 通过执行必要的操作来启动和运行一个最小可用的集群。它被故意设计为只关心启动集群，而不是之前的节点准备工作。同样的，诸如安装各种各样值得拥有的插件，例如 Kubernetes Dashboard、监控解决方案以及特定云提供商的插件，这些都不在它负责的范围。

&#8195;相反，我们期望由一个基于 kubeadm 从更高层设计的更加合适的工具来做这些事情；并且，理想情况下，使用 kubeadm 作为所有部署的基础将会使得创建一个符合期望的集群变得容易。

### 2、Kuberadm 功能
```bash
kubeadm init： 启动一个 Kubernetes 主节点
kubeadm join： 启动一个 Kubernetes 工作节点并且将其加入到集群
kubeadm upgrade： 更新一个 Kubernetes 集群到新版本
kubeadm config： 如果使用 v1.7.x 或者更低版本的 kubeadm 初始化集群，您需要对集群做一些配置以便使用 kubeadm upgrade 命令
kubeadm token： 管理 kubeadm join 使用的令牌
kubeadm reset： 还原 kubeadm init 或者 kubeadm join 对主机所做的任何更改
kubeadm version： 打印 kubeadm 版本
kubeadm alpha： 预览一组可用的新功能以便从社区搜集反馈
```
### 3、功能版本

<table border="0">
    <tr>
        <td><strong>Area<strong></td>
        <td><strong>Maturity Level<strong></td>
    </tr>
    <tr>
        <td>Command line UX</td>
        <td>GA</td>
    </tr>
    <tr>
        <td>Implementation</td>
        <td>GA</td>
    </tr>
    <tr>
        <td>Config file API</td>
        <td>beta</td>
    </tr>
    <tr>
        <td>CoreDNS</td>
        <td>GA</td>
    </tr>
    <tr>
        <td>kubeadm alpha subcommands</td>
        <td>alpha</td>
    </tr>
    <tr>
        <td>High availability</td>
        <td>alpha</td>
    </tr>
    <tr>
        <td>DynamicKubeletConfig</td>
        <td>alpha</td>
    </tr>
    <tr>
        <td>Self-hosting</td>
        <td>alpha</td>
    </tr>
</table>
            
## 二、前期准备

### 1、虚拟机分配说明

<table border="0">
    <tr>
        <td><strong>地址<strong></td>
        <td><strong>主机名</td>
        <td><strong>内存&CPU</td>
        <td><strong>角色</td>
    </tr>
    <tr>
        <td>10.19.2.200</td>
        <td>-</td>
        <td>-</td>
        <td>vip</td>
    </tr>
    <tr>
        <td>10.19.2.56</td>
        <td>k8s-master-01</td>
        <td>2C & 2G</td>
        <td>master</td>
    </tr>
    <tr>
        <td>10.19.2.57</td>
        <td>k8s-master-02</td>
        <td>2C & 2G</td>
        <td>master</td>
    </tr>
    <tr>
        <td>10.19.2.58</td>
        <td>k8s-master-03</td>
        <td>2C & 2G</td>
        <td>master</td>
    </tr>
    <tr>
        <td>10.19.2.246</td>
        <td>k8s-node-01</td>
        <td>4C & 8G</td>
        <td>node</td>
    </tr>
    <tr>
        <td>10.19.2.247</td>
        <td>k8s-node-02</td>
        <td>4C & 8G</td>
        <td>node</td>
    </tr>
    <tr>
        <td>10.19.2.248</td>
        <td>k8s-node-03</td>
        <td>4C & 8G</td>
        <td>node</td>
    </tr>
</table>

### 2、各个节点端口占用

- Master 节点

<table border="0">
    <tr>
        <td><strong>规则<strong></td>
        <td><strong>方向</td>
        <td><strong>端口范围</td>
        <td><strong>作用</td>
        <td><strong>使用者</td>
    </tr>
    <tr>
        <td>TCP</td>
        <td>Inbound 入口</td>
        <td>6443*</td>
        <td>Kubernetes API</td>
        <td>server All</td>
    </tr>
    <tr>
        <td>TCP</td>
        <td>Inbound 入口</td>
        <td>2379-2380</td>
        <td>etcd server</td>
        <td>client API kube-apiserver, etcd</td>
    </tr>
    <tr>
        <td>TCP</td>
        <td>Inbound 入口</td>
        <td>10250</td>
        <td>Kubernetes API</td>
        <td>Self, Control plane</td>
    </tr>
    <tr>
        <td>TCP</td>
        <td>Inbound 入口</td>
        <td>10251</td>
        <td>kube-scheduler</td>
        <td>Self</td>
    </tr>
    <tr>
        <td>TCP</td>
        <td>Inbound 入口</td>
        <td>10252</td>
        <td>kube-controller-manager</td>
        <td>Self</td>
    </tr>
</table>

- node 节点

<table border="0">
    <tr>
        <td><strong>规则<strong></td>
        <td><strong>方向</td>
        <td><strong>端口范围</td>
        <td><strong>作用</td>
        <td><strong>使用者</td>
    </tr>
    <tr>
        <td>TCP</td>
        <td>Inbound 入口</td>
        <td>10250</td>
        <td>Kubernetes API</td>
        <td>Self, Control plane</td>
    </tr>
    <tr>
        <td>TCP</td>
        <td>Inbound 入口</td>
        <td>30000-32767</td>
        <td>NodePort Services**</td>
        <td>All</td>
    </tr>
</table>
    
### 3、基础环境设置

&#8195;Kubernetes 需要一定的环境来保证正常运行，如各个节点时间同步，主机名称解析，关闭防火墙等等。

1、主机名称解析

&#8195;分布式系统环境中的多主机通信通常基于主机名称进行，这在 IP 地址存在变化的可能性时为主机提供了固定的访问人口，因此一般需要有专用的 DNS 服务负责解决各节点主机 不过，考虑到此处部署的是测试集群，因此为了降低系复杂度，这里将基于 hosts 的文件进行主机名称解析。

2、修改hosts

```bash
#分别进入不同服务器，进入 /etc/hosts 进行编辑

cat > /etc/hosts << \EOF
127.0.0.1     localhost  localhost.localdomain localhost4 localhost4.localdomain4
::1           localhost  localhost.localdomain localhost6 localhost6.localdomain6
10.19.2.200    master.k8s.io      k8s-vip
10.19.2.56     master01.k8s.io    k8s-master-01
10.19.2.57     master02.k8s.io    k8s-master-02
10.19.2.58     master03.k8s.io    k8s-master-03
10.19.2.246    node01.k8s.io      k8s-node-01
10.19.2.247    node01.k8s.io      k8s-node-02
10.19.2.248    node02.k8s.io      k8s-node-03
EOF
```

3、修改hostname

```bash
#分别进入不同的服务器修改 hostname 名称

# 修改 10.19.2.56 服务器
hostnamectl  set-hostname  k8s-master-01

# 修改 10.19.2.57 服务器
hostnamectl  set-hostname  k8s-master-02

# 修改 10.19.2.58 服务器
hostnamectl  set-hostname  k8s-master-03

# 修改 10.19.2.246 服务器
hostnamectl  set-hostname  k8s-node-01

# 修改 10.19.2.247 服务器
hostnamectl  set-hostname  k8s-node-02

# 修改 10.19.2.248 服务器
hostnamectl  set-hostname  k8s-node-03
```

4、主机时间同步

```bash
#将各个服务器的时间同步，并设置开机启动同步时间服务

systemctl start chronyd.service
systemctl enable chronyd.service
```

5、关闭防火墙服务
```bash
systemctl stop firewalld
systemctl disable firewalld
```

6、关闭并禁用SELinux
```bash
# 若当前启用了 SELinux 则需要临时设置其当前状态为 permissive
setenforce 0

# 编辑／etc/sysconfig selinux 文件，以彻底禁用 SELinux
sed -i 's/^SELINUX=enforcing$/SELINUX=disabled/' /etc/selinux/config

# 查看selinux状态
getenforce 
```
如果为permissive，则执行reboot重新启动即可

7、禁用 Swap 设备

&#8195;kubeadm 默认会预先检当前主机是否禁用了 Swap 设备，并在未用时强制止部署 过程因此，在主机内存资惊充裕的条件下，需要禁用所有的 Swap 设备

```
# 关闭当前已启用的所有 Swap 设备
swapoff -a && sysctl -w vm.swappiness=0

# 编辑 fstab 配置文件，注释掉标识为 Swap 设备的所有行
vi /etc/fstab

```

8、设置系统参数

&#8195;设置允许路由转发，不对bridge的数据进行处理

```bash
#创建 /etc/sysctl.d/k8s.conf 文件

cat > /etc/sysctl.d/k8s.conf << \EOF
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

#挂载br_netfilter
modprobe br_netfilter

#生效配置文件
sysctl -p /etc/sysctl.d/k8s.conf

#查看是否生成相关文件
ls /proc/sys/net/bridge
```

9、资源配置文件

`/etc/security/limits.conf` 是 Linux 资源使用配置文件，用来限制用户对系统资源的使用

```bash
echo "* soft nofile 65536" >> /etc/security/limits.conf
echo "* hard nofile 65536" >> /etc/security/limits.conf
echo "* soft nproc 65536"  >> /etc/security/limits.conf
echo "* hard nproc 65536"  >> /etc/security/limits.conf
echo "* soft  memlock  unlimited"  >> /etc/security/limits.conf
echo "* hard memlock  unlimited"  >> /etc/security/limits.conf
```

10、安装依赖包以及相关工具

```bash
yum install -y epel-release

yum install -y yum-utils device-mapper-persistent-data lvm2 net-tools conntrack-tools wget vim  ntpdate libseccomp libtool-ltdl
```

## 三、安装Keepalived

- keepalived介绍： 是集群管理中保证集群高可用的一个服务软件，其功能类似于heartbeat，用来防止单点故障
- Keepalived作用： 为haproxy提供vip（192.168.2.10）在三个haproxy实例之间提供主备，降低当其中一个haproxy失效的时对服务的影响。

### 1、yum安装Keepalived
```bash
# 安装keepalived
yum install -y keepalived
```

### 2、配置Keepalived
```bash
cat <<EOF > /etc/keepalived/keepalived.conf
! Configuration File for keepalived

# 主要是配置故障发生时的通知对象以及机器标识。
global_defs {
   # 标识本节点的字条串，通常为 hostname，但不一定非得是 hostname。故障发生时，邮件通知会用到。
   router_id LVS_k8s
}

# 用来做健康检查的，当时检查失败时会将 vrrp_instance 的 priority 减少相应的值。
vrrp_script check_haproxy {
    script "killall -0 haproxy"   #根据进程名称检测进程是否存活
    interval 3
    weight -2
    fall 10
    rise 2
}

# rp_instance用来定义对外提供服务的 VIP 区域及其相关属性。
vrrp_instance VI_1 {
    state MASTER   #当前节点为MASTER，其他两个节点设置为BACKUP
    interface eth0 #改为自己的网卡
    virtual_router_id 51
    priority 250
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass 35f18af7190d51c9f7f78f37300a0cbd
    }
    virtual_ipaddress {
        10.19.2.200   #虚拟ip，即VIP
    }
    track_script {
        check_haproxy
    }

}
EOF
```
当前节点的配置中 state 配置为 MASTER，其它两个节点设置为 BACKUP

```bash
配置说明：

    virtual_ipaddress： vip
    track_script： 执行上面定义好的检测的script
    interface： 节点固有IP（非VIP）的网卡，用来发VRRP包。
    virtual_router_id： 取值在0-255之间，用来区分多个instance的VRRP组播
    advert_int： 发VRRP包的时间间隔，即多久进行一次master选举（可以认为是健康查检时间间隔）。
    authentication： 认证区域，认证类型有PASS和HA（IPSEC），推荐使用PASS（密码只识别前8位）。
    state： 可以是MASTER或BACKUP，不过当其他节点keepalived启动时会将priority比较大的节点选举为MASTER，因此该项其实没有实质用途。
    priority： 用来选举master的，要成为master，那么这个选项的值最好高于其他机器50个点，该项取值范围是1-255（在此范围之外会被识别成默认值100）。
```

### 3、启动Keepalived
```bash
# 设置开机启动
systemctl enable keepalived

# 启动keepalived
systemctl start keepalived

# 查看启动状态
systemctl status keepalived
```

参考资料：

http://www.mydlq.club/article/4/
