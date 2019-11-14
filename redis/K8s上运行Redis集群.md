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
  nfs:
    server: 10.198.1.155
    path: "/data/nfs/redis/pv1"

---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs-vp2
spec:
  capacity:
    storage: 20Gi
  accessModes:
    - ReadWriteMany
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

Headless service是StatefulSet实现稳定网络标识的基础，我们需要提前创建。准备文件headless-service.yml如下：

```bash
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
kubectl create -f headless-service.yml

#查看service
kubectl get svc
```
可以看到，服务名称为redis-service，其CLUSTER-IP为None，表示这是一个“无头”服务。

## 4、创建Redis 集群节点

创建好Headless service后，就可以利用StatefulSet创建Redis 集群节点，这也是本文的核心内容。我们先创建redis.yml文件：


```bash
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
      resources:
        requests:
          storage: 200M
EOF

PodAntiAffinity:表示反亲和性，其决定了某个pod不可以和哪些Pod部署在同一拓扑域，可以用于将一个服务的POD分散在不同的主机或者拓扑域中，提高服务本身的稳定性。

matchExpressions:规定了Redis_Pod要尽量不要调度到包含app为redis的Node上，也即是说已经存在Redis的Node上尽量不要再分配Redis Pod了.

另外，根据StatefulSet的规则，我们生成的Redis的6个Pod的hostname会被依次命名为$(statefulset名称)-$(序号)，如下图所示：

$ kubectl get pods -o wide 
NAME                                            READY     STATUS      RESTARTS   AGE       IP             NODE            NOMINATED NODE
redis-app-0                                     1/1       Running     0          2h        172.17.24.3    192.168.0.144   <none>
redis-app-1                                     1/1       Running     0          2h        172.17.63.8    192.168.0.148   <none>
redis-app-2                                     1/1       Running     0          2h        172.17.24.8    192.168.0.144   <none>
redis-app-3                                     1/1       Running     0          2h        172.17.63.9    192.168.0.148   <none>
redis-app-4                                     1/1       Running     0          2h        172.17.24.9    192.168.0.144   <none>
redis-app-5                                     1/1       Running     0          2h        172.17.63.10   192.168.0.148   <none>

```

参考文档：

https://blog.csdn.net/zhutongcloud/article/details/90768390  在K8s上部署Redis集群
