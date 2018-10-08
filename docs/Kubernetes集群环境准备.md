# 一、k8s集群实验环境准备

  ![架构图](https://github.com/Lancger/opsfull/blob/master/images/K8S.png)

<table border="0">
    <tr>
        <td><strong>主机名</strong></td>
        <td><strong>IP地址（NAT）</strong></td>
        <td><strong>描述</strong></td>
    </tr>
     <tr>
        <td><strong>linux-node1.example.com</strong></td>
        <td>eth0:192.168.56.11</td>
        <td>Kubernets Master节点/Etcd节点</td>
    </tr>
    <tr>
        <td><strong>linux-node2.example.com</strong></td>
        <td>eth0:192.168.56.12</td>
        <td>Kubernets Node节点/ Etcd节点</td>
    </tr>
    <tr>
        <td><strong>linux-node3.example.com</strong></td>
        <td>eth0:192.168.56.13</td>
        <td>Kubernets Node节点/ Etcd节点</td>
    </tr>
</table>

# 二、准备工作
  
1、设置主机名
```
hostnamectl set-hostname linux-node1
hostnamectl set-hostname linux-node2
hostnamectl set-hostname linux-node3
```
2、设置部署节点(Master)到其它所有节点的SSH免密码登(包括本机)
```
[root@linux-node1 ~]# ssh-keygen -t rsa
[root@linux-node1 ~]# ssh-copy-id linux-node1
[root@linux-node1 ~]# ssh-copy-id linux-node2
[root@linux-node1 ~]# ssh-copy-id linux-node3
```
3、绑定主机host
```
cat > /etc/hosts <<EOF
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
192.168.56.11 linux-node1
192.168.56.12 linux-node2
192.168.56.13 linux-node3
EOF
```

4、关闭防火墙和selinux
```
#关闭防火墙
systemctl disable firewalld
systemctl stop firewalld

#关闭selinux
sed -i "s/SELINUX=enforcing/SELINUX=disabled/g" /etc/sysconfig/selinux
sed -i "s/SELINUXTYPE=targeted/SELINUXTYPE=disabled/g" /etc/sysconfig/selinux
setenforce 0
```

5、其他配置
```
yum install -y ntpdate wget lrzsz vim net-tools

#加入crontab
1 * * * * /usr/sbin/ntpdate ntp1.aliyun.com >/dev/null 2>&1

#设置时区
cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

#SSH登录慢
sed -i "s/#UseDNS yes/UseDNS no/"  /etc/ssh/sshd_config
sed -i "s/GSSAPIAuthentication yes/GSSAPIAuthentication no/"  /etc/ssh/sshd_config
systemctl restart sshd.service
```

6、软件包下载

k8s-v1.12.0版本网盘地址: https://pan.baidu.com/s/10HWLaLAKUdw08HVfDvUfBQ

```
#所有文件存放在/opt/kubernetes目录下
mkdir -p /opt/kubernetes/{cfg,bin,ssl,log}

#使用二进制方式进行部署
官网下载地址: https://github.com/kubernetes/kubernetes/blob/master/CHANGELOG-1.12.md#downloads-for-v1121

#添加环境变量
vim /root/.bash_profile

PATH=$PATH:$HOME/bin:/opt/kubernetes/bin

source /root/.bash_profile
```
![官网下载链接](https://github.com/Lancger/opsfull/blob/master/images/k8s-soft.jpg)
