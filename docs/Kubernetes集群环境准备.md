# 一、k8s集群实验环境准备

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

  ![安装流程](https://github.com/Lancger/opsfull/blob/master/images/%E5%AE%89%E8%A3%85%E6%B5%81%E7%A8%8B.png)


# 二、准备工作

  ![架构图](https://github.com/Lancger/opsfull/blob/master/images/K8S.png)

  
  1、设置主机名
```
hostnamectl set-hostname linux-node1
hostnamectl set-hostname linux-node2
hostnamectl set-hostname linux-node3
```
2、设置部署节点到其它所有节点的SSH免密码登(包括本机)
```
[root@linux-node1 ~]# ssh-keygen -t rsa
[root@linux-node1 ~]# ssh-copy-id linux-node1
[root@linux-node1 ~]# ssh-copy-id linux-node2
[root@linux-node1 ~]# ssh-copy-id linux-node3
```
