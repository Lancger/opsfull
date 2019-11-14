Table of Contents
=================

   * [一、前言](#一前言)
   * [二、准备操作](#二准备操作)
   * [三、StatefulSet简介](#三statefulset简介)
   * [四、部署过程](#四部署过程)
      * [1、创建NFS存储](#1创建nfs存储)
      * [2、创建PV](#2创建pv)
      * [3、创建Configmap](#3创建configmap)
      * [4、创建Headless service](#4创建headless-service)
      * [4、创建Redis 集群节点](#4创建redis-集群节点)
      * [5、初始化Redis集群](#5初始化redis集群)
      * [6、创建用于访问Service](#6创建用于访问service)
   * [五、测试主从切换](#五测试主从切换)
   * [六、疑问点](#六疑问点)
   
# 一、前言

架构原理:

`每个Master都可以拥有多个Slave。当Master下线后，Redis集群会从多个Slave中选举出一个新的Master作为替代，而旧Master重新上线后变成新Master的Slave。`

# 二、准备操作

本次部署主要基于该项目：

`https://github.com/zuxqoj/kubernetes-redis-cluster`

其包含了两种部署Redis集群的方式：
```bash
StatefulSet

Service & Deployment
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
mkdir -p /data/nfs/redis/pv{1..6}

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
kubectl delete -f pv.yaml

cat >pv.yaml<<\EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs-pv1
spec:
  capacity:
    storage: 20Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: nfs
  nfs:
    server: 10.198.1.155
    path: "/data/nfs/redis/pv1"

---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs-pv2
spec:
  capacity:
    storage: 20Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: nfs
  nfs:
    server: 10.198.1.155
    path: "/data/nfs/redis/pv2"

---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs-pv3
spec:
  capacity:
    storage: 20Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: nfs
  nfs:
    server: 10.198.1.155
    path: "/data/nfs/redis/pv3"

---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs-pv4
spec:
  capacity:
    storage: 20Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: nfs
  nfs:
    server: 10.198.1.155
    path: "/data/nfs/redis/pv4"

---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs-pv5
spec:
  capacity:
    storage: 20Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: nfs
  nfs:
    server: 10.198.1.155
    path: "/data/nfs/redis/pv5"

---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs-pv6
spec:
  capacity:
    storage: 20Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: nfs
  nfs:
    server: 10.198.1.155
    path: "/data/nfs/redis/pv6"
EOF

kubectl apply -f pv.yaml
```

## 3、创建Configmap

这里，我们可以直接将Redis的配置文件转化为Configmap，这是一种更方便的配置读取方式。配置文件redis.conf如下

```bash
#配置文件redis.conf
cat >redis.conf<<\EOF 
appendonly yes
cluster-enabled yes
cluster-config-file /var/lib/redis/nodes.conf
cluster-node-timeout 5000
dir /var/lib/redis
port 6379
EOF

#删除名为redis-conf的Configmap
kubectl delete configmap redis-conf

#创建名为redis-conf的Configmap
kubectl create configmap redis-conf --from-file=redis.conf

#查看创建的configmap
$ kubectl describe cm redis-conf
Name:         redis-conf
Namespace:    default
Labels:       <none>
Annotations:  <none>

Data
====
redis.conf:
----
appendonly yes
cluster-enabled yes
cluster-config-file /var/lib/redis/nodes.conf
cluster-node-timeout 5000
dir /var/lib/redis
port 6379

Events:  <none>
#如上，redis.conf中的所有配置项都保存到redis-conf这个Configmap中。
```

## 4、创建Headless service

Headless service是StatefulSet实现稳定网络标识的基础，我们需要提前创建。准备文件headless-service.yaml如下：

```bash
#删除svc
kubectl delete -f headless-service.yaml

#编写svc
cat >headless-service.yaml<<\EOF 
apiVersion: v1
kind: Service
metadata:
  name: redis-service
  labels:
    app: redis
spec:
  ports:
  - name: redis-port
    port: 6379
  clusterIP: None
  selector:
    app: redis
    appCluster: redis-cluster
EOF

#创建svc
kubectl create -f headless-service.yaml

#查看service
$ kubectl get svc
NAME            TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)    AGE
redis-service   ClusterIP   None         <none>        6379/TCP   0s
```
可以看到，服务名称为redis-service，其CLUSTER-IP为None，表示这是一个“无头”服务。

## 4、创建Redis 集群节点

创建好Headless service后，就可以利用StatefulSet创建Redis 集群节点，这也是本文的核心内容。我们先创建redis.yml文件：

```bash
#清理pvc资源
kubectl delete pvc redis-data-redis-app-{0..5}

#清理pod资源
kubectl delete -f redis.yaml

#编写yaml
cat >redis.yaml<<\EOF
apiVersion: apps/v1beta1
kind: StatefulSet
metadata:
  name: redis-app
spec:
  serviceName: "redis-service"
  replicas: 6
  template:
    metadata:
      labels:
        app: redis
        appCluster: redis-cluster
    spec:
      terminationGracePeriodSeconds: 20
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - redis
              topologyKey: kubernetes.io/hostname
      containers:
      - name: redis
        image: redis
        command:
          - "redis-server"  #redis启动命令
        args:
          - "/etc/redis/redis.conf"  #redis-server后面跟的参数,换行代表空格
          - "--protected-mode"  #允许外网访问
          - "no"
        resources:  #资源
          requests:  #请求的资源
            cpu: "100m"  #m代表千分之,相当于0.1 个cpu资源
            memory: "100Mi"  #内存100m大小
        ports:
            - name: redis
              containerPort: 6379
              protocol: "TCP"
            - name: cluster
              containerPort: 16379
              protocol: "TCP"
        volumeMounts:
          - name: "redis-conf"  #挂载configmap生成的文件
            mountPath: "/etc/redis"  #挂载到哪个路径下
          - name: "redis-data"  #挂载持久卷的路径
            mountPath: "/var/lib/redis"
      volumes:
      - name: "redis-conf"  #引用configMap卷
        configMap:
          name: "redis-conf"
          items:
            - key: "redis.conf"  #创建configMap指定的名称
              path: "redis.conf"  #里面的那个文件--from-file参数后面的文件
  volumeClaimTemplates:  #进行pvc持久卷声明
  - metadata:
      name: redis-data
    spec:
      accessModes: [ "ReadWriteMany" ]
      storageClassName: "nfs"  #--注意这里是使用nfs storageClass，如果没有改默认的，可以忽略不写
      resources:
        requests:
          storage: 20Gi
EOF

#创建资源
kubectl apply -f redis.yaml

PodAntiAffinity:表示反亲和性，其决定了某个pod不可以和哪些Pod部署在同一拓扑域，可以用于将一个服务的POD分散在不同的主机或者拓扑域中，提高服务本身的稳定性。

matchExpressions:规定了Redis_Pod要尽量不要调度到包含app为redis的Node上，也即是说已经存在Redis的Node上尽量不要再分配Redis Pod了.

另外，根据StatefulSet的规则，我们生成的Redis的6个Pod的hostname会被依次命名为$(statefulset名称)-$(序号)，如下图所示：

```

```bash
# kubectl get pods -o wide 
NAME                                            READY     STATUS      RESTARTS   AGE       IP             NODE            NOMINATED NODE
redis-app-0                                     1/1       Running     0          2h        172.17.24.3    192.168.0.144   <none>
redis-app-1                                     1/1       Running     0          2h        172.17.63.8    192.168.0.148   <none>
redis-app-2                                     1/1       Running     0          2h        172.17.24.8    192.168.0.144   <none>
redis-app-3                                     1/1       Running     0          2h        172.17.63.9    192.168.0.148   <none>
redis-app-4                                     1/1       Running     0          2h        172.17.24.9    192.168.0.144   <none>
redis-app-5                                     1/1       ContainerCreating     0          2h        172.17.63.10   192.168.0.148   <none>

如上，可以看到这些Pods在部署时是以{0…N-1}的顺序依次创建的。注意，直到redis-app-0状态启动后达到Running状态之后，redis-app-1 才开始启动。

同时，每个Pod都会得到集群内的一个DNS域名，格式为$(podname).$(service name).$(namespace).svc.cluster.local ，也即是：

redis-app-0.redis-service.default.svc.cluster.local
redis-app-1.redis-service.default.svc.cluster.local
...以此类推...

这里我们可以验证一下
#kubectl run --rm curl --image=radial/busyboxplus:curl -it
kubectl run --rm -i --tty busybox --image=busybox:1.28 /bin/sh

$ nslookup redis-app-0.redis-service   #注意格式 $(podname).$(service name).$(namespace)
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      redis-app-0.redis-service
Address 1: 172.17.24.3 redis-app-0.redis-service.default.svc.cluster.local

在K8S集群内部，这些Pod就可以利用该域名互相通信。我们可以使用busybox镜像的nslookup检验这些域名(一条命令)

$ kubectl run -it --rm --image=busybox:1.28 --restart=Never busybox -- nslookup redis-app-0.redis-service
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      redis-app-0.redis-service
Address 1: 172.17.24.3 redis-app-0.redis-service.default.svc.cluster.local
pod "busybox" deleted

可以看到, redis-app-0 的IP为172.17.24.3。当然，若Redis Pod迁移或是重启(我们可以手动删除掉一个Redis Pod来测试),IP是会改变的,但是Pod的域名、SRV records、A record都不会改变。

另外可以发现，我们之前创建的pv都被成功绑定了：

$ kubectl get pv|grep nfs-pv
nfs-pv1                                    20Gi       RWX            Retain           Bound      default/redis-data-redis-app-1                  nfs                            65s
nfs-pv2                                    20Gi       RWX            Retain           Bound      default/redis-data-redis-app-0                  nfs                            65s
nfs-pv3                                    20Gi       RWX            Retain           Bound      default/redis-data-redis-app-2                  nfs                            65s
nfs-pv4                                    20Gi       RWX            Retain           Bound      default/redis-data-redis-app-5                  nfs                            65s
nfs-pv5                                    20Gi       RWX            Retain           Bound      default/redis-data-redis-app-3                  nfs                            65s
nfs-pv6                                    20Gi       RWX            Retain           Bound      default/redis-data-redis-app-4                  nfs                            65s

查看pvc资源
$ kubectl get pvc
NAME                     STATUS   VOLUME    CAPACITY   ACCESS MODES   STORAGECLASS   AGE
redis-data-redis-app-0   Bound    nfs-pv2   20Gi       RWX            nfs            96s
redis-data-redis-app-1   Bound    nfs-pv1   20Gi       RWX            nfs            86s
redis-data-redis-app-2   Bound    nfs-pv3   20Gi       RWX            nfs            75s
redis-data-redis-app-3   Bound    nfs-pv5   20Gi       RWX            nfs            69s
redis-data-redis-app-4   Bound    nfs-pv6   20Gi       RWX            nfs            62s
redis-data-redis-app-5   Bound    nfs-pv4   20Gi       RWX            nfs            56s
```

## 5、初始化Redis集群

创建好6个Redis Pod后，我们还需要利用常用的Redis-tribe工具进行集群的初始化

创建Ubuntu容器

由于Redis集群必须在所有节点启动后才能进行初始化，而如果将初始化逻辑写入Statefulset中，则是一件非常复杂而且低效的行为。这里，本人不得不称赞一下原项目作者的思路，值得学习。也就是说，我们可以在K8S上创建一个额外的容器，专门用于进行K8S集群内部某些服务的管理控制。
这里，我们专门启动一个Ubuntu的容器，可以在该容器中安装Redis-tribe，进而初始化Redis集群，执行：

```bash
1、#创建一个ubuntu容器
kubectl run -it ubuntu --image=ubuntu --restart=Never /bin/bash

#进入到容器
kubectl exec -it ubuntu /bin/bash

2、#我们使用阿里云的Ubuntu源，执行
$ cat > /etc/apt/sources.list << EOF
deb http://mirrors.aliyun.com/ubuntu/ bionic main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ bionic main restricted universe multiverse

deb http://mirrors.aliyun.com/ubuntu/ bionic-security main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ bionic-security main restricted universe multiverse

deb http://mirrors.aliyun.com/ubuntu/ bionic-updates main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ bionic-updates main restricted universe multiverse

deb http://mirrors.aliyun.com/ubuntu/ bionic-proposed main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ bionic-proposed main restricted universe multiverse
 
deb http://mirrors.aliyun.com/ubuntu/ bionic-backports main restricted universe multiverse
deb-src http://mirrors.aliyun.com/ubuntu/ bionic-backports main restricted universe multiverse
EOF

3、#成功后，原项目要求执行如下命令安装基本的软件环境：
apt-get update
apt-get install -y vim wget python2.7 python-pip redis-tools dnsutils

4、#初始化集群
首先，我们需要安装redis-trib
pip install redis-trib==0.5.1

然后，创建只有Master节点的集群
redis-trib.py create \
  `dig +short redis-app-0.redis-service.default.svc.cluster.local`:6379 \
  `dig +short redis-app-1.redis-service.default.svc.cluster.local`:6379 \
  `dig +short redis-app-2.redis-service.default.svc.cluster.local`:6379

其次，为每个Master添加Slave
redis-trib.py replicate \
  --master-addr `dig +short redis-app-0.redis-service.default.svc.cluster.local`:6379 \
  --slave-addr `dig +short redis-app-3.redis-service.default.svc.cluster.local`:6379

redis-trib.py replicate \
  --master-addr `dig +short redis-app-1.redis-service.default.svc.cluster.local`:6379 \
  --slave-addr `dig +short redis-app-4.redis-service.default.svc.cluster.local`:6379

redis-trib.py replicate \
  --master-addr `dig +short redis-app-2.redis-service.default.svc.cluster.local`:6379 \
  --slave-addr `dig +short redis-app-5.redis-service.default.svc.cluster.local`:6379

至此，我们的Redis集群就真正创建完毕了，连到任意一个Redis Pod中检验一下：
$ kubectl exec -it redis-app-2 /bin/bash
root@redis-app-2:/data# /usr/local/bin/redis-cli -c
127.0.0.1:6379> cluster nodes
5d3e77f6131c6f272576530b23d1cd7592942eec 172.17.24.3:6379@16379 master - 0 1559628533000 1 connected 0-5461
a4b529c40a920da314c6c93d17dc603625d6412c 172.17.63.10:6379@16379 master - 0 1559628531670 6 connected 10923-16383
368971dc8916611a86577a8726e4f1f3a69c5eb7 172.17.24.9:6379@16379 slave 0025e6140f85cb243c60c214467b7e77bf819ae3 0 1559628533672 4 connected
0025e6140f85cb243c60c214467b7e77bf819ae3 172.17.63.8:6379@16379 master - 0 1559628533000 2 connected 5462-10922
6d5ee94b78b279e7d3c77a55437695662e8c039e 172.17.24.8:6379@16379 myself,slave a4b529c40a920da314c6c93d17dc603625d6412c 0 1559628532000 5 connected
2eb3e06ce914e0e285d6284c4df32573e318bc01 172.17.63.9:6379@16379 slave 5d3e77f6131c6f272576530b23d1cd7592942eec 0 1559628533000 3 connected
127.0.0.1:6379> cluster info
cluster_state:ok
cluster_slots_assigned:16384
cluster_slots_ok:16384
cluster_slots_pfail:0
cluster_slots_fail:0
cluster_known_nodes:6
cluster_size:3
cluster_current_epoch:6
cluster_my_epoch:6
cluster_stats_messages_ping_sent:14910
cluster_stats_messages_pong_sent:15139
cluster_stats_messages_sent:30049
cluster_stats_messages_ping_received:15139
cluster_stats_messages_pong_received:14910
cluster_stats_messages_received:30049
127.0.0.1:6379> 

另外，还可以在NFS上查看Redis挂载的数据：
$ ll /data/nfs/redis/pv3
total 12
-rw-r--r-- 1 root root  92 Jun  4 11:36 appendonly.aof
-rw-r--r-- 1 root root 175 Jun  4 11:36 dump.rdb
-rw-r--r-- 1 root root 794 Jun  4 11:49 nodes.conf
```

## 6、创建用于访问Service

前面我们创建了用于实现StatefulSet的Headless Service，但该Service没有Cluster Ip，因此不能用于外界访问。所以，我们还需要创建一个Service，专用于为Redis集群提供访问和负载均衡：

```bash
#删除服务
kubectl delete -f redis-access-service.yaml

#编写yaml
cat >redis-access-service.yaml<<\EOF
apiVersion: v1
kind: Service
metadata:
  name: redis-access-service
  labels:
    app: redis
spec:
  type: NodePort
  ports:
  - name: redis-port
    protocol: "TCP"
    port: 6379
    targetPort: 6379
    nodePort: 30010
  selector:
    app: redis
    appCluster: redis-cluster
EOF

#如上，该Service名称为 redis-access-service，在K8S集群中暴露6379端口，并且会对labels name为app: redis或appCluster: redis-cluster的pod进行负载均衡。

#创建服务
kubectl apply -f redis-access-service.yaml

#查看svc
$ kubectl get svc redis-access-service -o wide
NAME                   TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE   SELECTOR
redis-access-service   NodePort   10.111.59.191   <none>        6379:30010/TCP   83m   app=redis,appCluster=redis-cluster

#如上，在K8S集群中，所有应用都可以通过 10.111.59.191:6379 来访问Redis集群。当然，为了方便测试，我们也可以为Service添加一个NodePort映射到物理机30010上。
#查看svc详情
$ kubectl describe svc redis-access-service
Name:                     redis-access-service
Namespace:                default
Labels:                   app=redis
Annotations:              kubectl.kubernetes.io/last-applied-configuration:
                            {"apiVersion":"v1","kind":"Service","metadata":{"annotations":{},"labels":{"app":"redis"},"name":"redis-access-service","namespace":"defau...
Selector:                 app=redis,appCluster=redis-cluster
Type:                     NodePort
IP:                       10.111.59.191
Port:                     redis-port  6379/TCP
TargetPort:               6379/TCP
NodePort:                 redis-port  30010/TCP
Endpoints:                10.244.1.230:6379,10.244.1.231:6379,10.244.1.232:6379 + 3 more...
Session Affinity:         None
External Traffic Policy:  Cluster
Events:                   <none>

#集群内测试（service ip 测试）
yum install redis -y

redis-cli -h 10.111.59.191 -p 6379 -c
10.111.59.191:6379> CLUSTER info
cluster_state:ok
cluster_slots_assigned:16384
cluster_slots_ok:16384
cluster_slots_pfail:0
cluster_slots_fail:0
cluster_known_nodes:5
cluster_size:3
cluster_current_epoch:3
cluster_my_epoch:3
cluster_stats_messages_ping_sent:766
cluster_stats_messages_pong_sent:790
cluster_stats_messages_meet_sent:2
cluster_stats_messages_sent:1558
cluster_stats_messages_ping_received:787
cluster_stats_messages_pong_received:768
cluster_stats_messages_meet_received:3
cluster_stats_messages_received:1558

#宿主机端口测试(使用集群协议测试)
redis-cli -h 10.198.1.156 -p 30010 -c
10.198.1.156:30010> cluster info
cluster_state:ok
cluster_slots_assigned:16384
cluster_slots_ok:16384
cluster_slots_pfail:0
cluster_slots_fail:0
cluster_known_nodes:5
cluster_size:3
cluster_current_epoch:3
cluster_my_epoch:2
cluster_stats_messages_ping_sent:907
cluster_stats_messages_pong_sent:901
cluster_stats_messages_meet_sent:3
cluster_stats_messages_sent:1811
cluster_stats_messages_ping_received:900
cluster_stats_messages_pong_received:910
cluster_stats_messages_meet_received:1
cluster_stats_messages_received:1811
```

# 五、测试主从切换

在K8S上搭建完好Redis集群后，我们最关心的就是其原有的高可用机制是否正常。这里，我们可以任意挑选一个Master的Pod来测试集群的主从切换机制，如redis-app-0：

```bash
[root@master redis]# kubectl get pods redis-app-0 -o wide
NAME          READY     STATUS    RESTARTS   AGE       IP            NODE            NOMINATED NODE
redis-app-1   1/1       Running   0          3h        172.17.24.3   192.168.0.144   <none>

进入redis-app-0查看：
[root@master redis]# kubectl exec -it redis-app-0 /bin/bash
root@redis-app-0:/data# /usr/local/bin/redis-cli -c
127.0.0.1:6379> role
1) "master"
2) (integer) 13370
3) 1) 1) "172.17.63.9"
      2) "6379"
      3) "13370"
127.0.0.1:6379> 

如上可以看到，app-0为master，slave为172.17.63.9即redis-app-3。

接着，我们手动删除redis-app-0：
[root@master redis]# kubectl delete pod redis-app-0
pod "redis-app-0" deleted
[root@master redis]#  kubectl get pod redis-app-0 -o wide
NAME          READY     STATUS    RESTARTS   AGE       IP            NODE            NOMINATED NODE
redis-app-0   1/1       Running   0          4m        172.17.24.3   192.168.0.144   <none>

我们再进入redis-app-0内部查看：
[root@master redis]# kubectl exec -it redis-app-0 /bin/bash
root@redis-app-0:/data# /usr/local/bin/redis-cli -c
127.0.0.1:6379> role
1) "slave"
2) "172.17.63.9"
3) (integer) 6379
4) "connected"
5) (integer) 13958

如上，redis-app-0变成了slave，从属于它之前的从节点172.17.63.9即redis-app-3
```

# 六、疑问点

1、pod重启，ip变了，集群健康性如何维护
```
至此，大家可能会疑惑，前面讲了这么多似乎并没有体现出StatefulSet的作用，其提供的稳定标志redis-app-*仅在初始化集群的时候用到，而后续Redis Pod的通信或配置文件中并没有使用该标志。我想说，是的，本文使用StatefulSet部署Redis确实没有体现出其优势，还不如介绍Zookeeper集群来的明显，不过没关系，学到知识就好。

那为什么没有使用稳定的标志，Redis Pod也能正常进行故障转移呢？这涉及了Redis本身的机制。因为，Redis集群中每个节点都有自己的NodeId（保存在自动生成的nodes.conf中），并且该NodeId不会随着IP的变化和变化，这其实也是一种固定的网络标志。也就是说，就算某个Redis Pod重启了，该Pod依然会加载保存的NodeId来维持自己的身份。我们可以在NFS上查看redis-app-1的nodes.conf文件

$ cat /usr/local/k8s/redis/pv1/nodes.conf 
96689f2018089173e528d3a71c4ef10af68ee462 192.168.169.209:6379@16379 slave d884c4971de9748f99b10d14678d864187a9e5d3 0 1526460952651 4 connected
237d46046d9b75a6822f02523ab894928e2300e6 192.168.169.200:6379@16379 slave c15f378a604ee5b200f06cc23e9371cbc04f4559 0 1526460952651 1 connected
c15f378a604ee5b200f06cc23e9371cbc04f4559 192.168.169.197:6379@16379 master - 0 1526460952651 1 connected 10923-16383
d884c4971de9748f99b10d14678d864187a9e5d3 192.168.169.205:6379@16379 master - 0 1526460952651 4 connected 5462-10922
c3b4ae23c80ffe31b7b34ef29dd6f8d73beaf85f 192.168.169.198:6379@16379 myself,slave c8a8f70b4c29333de6039c47b2f3453ed11fb5c2 0 1526460952565 3 connected
c8a8f70b4c29333de6039c47b2f3453ed11fb5c2 192.168.169.201:6379@16379 master - 0 1526460952651 6 connected 0-5461
vars currentEpoch 6 lastVoteEpoch 4

如上，第一列为NodeId，稳定不变；第二列为IP和端口信息，可能会改变。

这里，我们介绍NodeId的两种使用场景：

当某个Slave Pod断线重连后IP改变，但是Master发现其NodeId依旧， 就认为该Slave还是之前的Slave。

当某个Master Pod下线后，集群在其Slave中选举重新的Master。待旧Master上线后，集群发现其NodeId依旧，会让旧Master变成新Master的slave。
```

2、pvc绑定不上报错(storageclass.storage.k8s.io "nfs" not found报错)

```
$ kubectl describe pvc redis-data-redis-app-0

Warning  ProvisioningFailed  14s (x2 over 24s)  persistentvolume-controller  storageclass.storage.k8s.io "nfs" not found

#原因为创建pv的时候，没有指定
storageClassName: nfs
```

参考文档：

https://cloud.tencent.com/developer/article/1392872  redis动态扩容

https://blog.csdn.net/zhutongcloud/article/details/90768390  部署Redis集群

https://www.jianshu.com/p/65c4baadf5d9  redis故障切换nodeid原因
