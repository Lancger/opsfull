# 一、前言

架构原理：每个Master都可以拥有多个Slave。当Master下线后，Redis集群会从多个Slave中选举出一个新的Master作为替代，而旧Master重新上线后变成新Master的Slave。

# 二、准备操作

本次部署主要基于该项目：

`https://github.com/zuxqoj/kubernetes-redis-cluster`

其包含了两种部署Redis集群的方式：
```bash
StatefulSet
Service&Deployment
```
两种方式各有优劣，对于像Redis、Mongodb、Zookeeper等有状态的服务，使用StatefulSet是首选方式。本文将主要介绍如何使用StatefulSet进行Redis集群的部署。

# 三、StatefulSet简介

- 1、RC、Deployment、DaemonSet都是面向无状态的服务，它们所管理的Pod的IP、名字，启停顺序等都是随机的，而StatefulSet是什么？顾名思义，有状态的集合，管理所有有状态的服务，比如MySQL、MongoDB集群等。

- 2、StatefulSet本质上是Deployment的一种变体，在v1.9版本中已成为GA版本，它为了解决有状态服务的问题，它所管理的Pod拥有固定的Pod名称，启停顺序，在StatefulSet中，Pod名字称为网络标识(hostname)，还必须要用到共享存储。

- 3、在Deployment中，与之对应的服务是service，而在StatefulSet中与之对应的headless service，headless service，即无头服务，与service的区别就是它没有Cluster IP，解析它的名称时将返回该Headless Service对应的全部Pod的Endpoint列表。

- 4、除此之外，StatefulSet在Headless Service的基础上又为StatefulSet控制的每个Pod副本创建了一个DNS域名，这个域名的格式为：
```bash
$(podname).(headless server name)   
FQDN： $(podname).(headless server name).namespace.svc.cluster.local
```
- 5、也即是说，对于有状态服务，我们最好使用固定的网络标识（如域名信息）来标记节点，当然这也需要应用程序的支持（如Zookeeper就支持在配置文件中写入主机域名）。

- 6、StatefulSet基于Headless Service（即没有Cluster IP的Service）为Pod实现了稳定的网络标志（包括Pod的hostname和DNS Records），在Pod重新调度后也保持不变。同时，结合PV/PVC，StatefulSet可以实现稳定的持久化存储，就算Pod重新调度后，还是能访问到原先的持久化数据。

- 7、以下为使用StatefulSet部署Redis的架构，无论是Master还是Slave，都作为StatefulSet的一个副本，并且数据通过PV进行持久化，对外暴露为一个Service，接受客户端请求。


# 四、部署过程

```bash
1.创建NFS存储
2.创建PV
3.创建PVC
4.创建Configmap
5.创建headless服务
6.创建Redis StatefulSet
7.初始化Redis集群
```
## 1、创建NFS存储

创建NFS存储主要是为了给Redis提供稳定的后端存储，当Redis的Pod重启或迁移后，依然能获得原先的数据。这里，我们先要创建NFS，然后通过使用PV为Redis挂载一个远程的NFS路径。

```bash
yum -y install nfs-utils   #主包提供文件系统
yum -y install rpcbind     #提供rpc协议
```
然后，新增/etc/exports文件，用于设置需要共享的路径

```bash
$ cat /etc/exports
/data/nfs/redis/pv1 *(rw,no_root_squash,sync,insecure)
/data/nfs/redis/pv2 *(rw,no_root_squash,sync,insecure)
/data/nfs/redis/pv3 *(rw,no_root_squash,sync,insecure)
/data/nfs/redis/pv4 *(rw,no_root_squash,sync,insecure)
/data/nfs/redis/pv5 *(rw,no_root_squash,sync,insecure)
/data/nfs/redis/pv6 *(rw,no_root_squash,sync,insecure)

#创建相应目录
mkdir -p //data/nfs/redis/pv{1..6}

#接着，启动NFS和rpcbind服务
systemctl restart rpcbind
systemctl restart nfs
systemctl enable nfs
systemctl enable rpcbind

#查看
exportfs -v

#客户端
yum -y install nfs-utils

#查看存储端共享
showmount -e localhost
```

## 2、创建PV

每一个Redis Pod都需要一个独立的PV来存储自己的数据，因此可以创建一个pv.yaml文件，包含6个PV

```bash

```


参考文档：

https://blog.csdn.net/zhutongcloud/article/details/90768390  在K8s上部署Redis集群
