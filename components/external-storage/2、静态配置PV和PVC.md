Table of Contents
=================
   * [目录](#目录)
      * [介绍](#介绍)
         * [01. 部署目的](#01-部署目的)
         * [02. 创建PV](#02-部署目的)
# 目录

# 介绍

作为准备工作，我们已经在 k8s同一局域内网节点上搭建了一个 NFS 服务器，目录为 /data/nfs

## 静态申请PV卷

### 01. 部署目的

nfs-server上操作，添加pv卷对应目录,这里创建2个pv卷，则添加2个pv卷的目录作为挂载点。

```bash
# 创建pv卷对应的目录
mkdir -p /data/nfs/pv001
mkdir -p /data/nfs/pv002

# 配置exportrs
$ vim /etc/exports
/data/nfs *(rw,no_root_squash,sync,insecure)
/data/nfs/pv001 *(rw,no_root_squash,sync,insecure)
/data/nfs/pv002 *(rw,no_root_squash,sync,insecure)

# 配置生效
exportfs -r

# 重启rpcbind、nfs服务
systemctl restart rpcbind && systemctl restart nfs

# 查看挂载点
$ showmount -e 192.168.56.11
Export list for 192.168.56.11:
/data/nfs/pv002 *
/data/nfs/pv001 *
/data/nfs       *
```

### 02. PV配置参数介绍

```bash
配置说明：

① capacity 指定 PV 的容量为 20G。

② accessModes 指定访问模式为 ReadWriteOnce，支持的访问模式有：
    ReadWriteOnce – PV 能以 read-write 模式 mount 到单个节点。
    ReadOnlyMany – PV 能以 read-only 模式 mount 到多个节点。
    ReadWriteMany – PV 能以 read-write 模式 mount 到多个节点。
    
③ persistentVolumeReclaimPolicy 指定当 PV 的回收策略为 Recycle，支持的策略有：
    Retain – 就是保留现场，K8S什么也不做，需要管理员手动去处理PV里的数据，处理完后，再手动删除PV
    Recycle – K8S会将PV里的数据删除，然后把PV的状态变成Available，又可以被新的PVC绑定使用
    Delete – K8S会自动删除该PV及里面的数据
    
④ storageClassName 指定 PV 的 class 为 nfs。相当于为 PV 设置了一个分类，PVC 可以指定 class 申请相应 class 的 PV。

⑤ 指定 PV 在 NFS 服务器上对应的目录。

一般来说，PV和PVC的生命周期分为5个阶段：
    Provisioning，即PV的创建，可以直接创建PV（静态方式），也可以使用StorageClass动态创建
    Binding，将PV分配给PVC
    Using，Pod通过PVC使用该Volume
    Releasing，Pod释放Volume并删除PVC
    Reclaiming，回收PV，可以保留PV以便下次使用，也可以直接从云存储中删除

根据这5个阶段，Volume的状态有以下4种：
    Available：可用
    Bound：已经分配给PVC
    Released：PVC解绑但还未执行回收策略
    Failed：发生错误

变成Released的PV会根据定义的回收策略做相应的回收工作。有三种回收策略：
    Retain 就是保留现场，K8S什么也不做，等待用户手动去处理PV里的数据，处理完后，再手动删除PV
    Delete K8S会自动删除该PV及里面的数据
    Recycle K8S会将PV里的数据删除，然后把PV的状态变成Available，又可以被新的PVC绑定使用
```

下面创建2个名为pv001和pv002的PV卷，配置文件 nfs-pv001.yaml 如下

1、nfs-pv001.yaml
```bash
# 清理pv资源
kubectl delete -f nfs-pv001.yaml

# 编写pv资源文件
cat > nfs-pv001.yaml <<\EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs-pv001
  labels:
    pv: nfs-pv001
spec:
  capacity:
    storage: 20Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Recycle
  storageClassName: nfs
  nfs:
    path: /data/nfs/pv001
    server: 192.168.56.11
EOF

# 部署pv到集群中
kubectl apply -f nfs-pv001.yaml
```

2、nfs-pv002.yaml

```bash
# 清理pv资源
kubectl delete -f nfs-pv002.yaml

# 编写pv资源文件
cat > nfs-pv002.yaml <<\EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs-pv002
  labels:
    pv: nfs-pv002
spec:
  capacity:
    storage: 30Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Recycle
  storageClassName: nfs
  nfs:
    path: /data/nfs/pv002
    server: 192.168.56.11
EOF

# 部署pv到集群中
kubectl apply -f nfs-pv002.yaml
```

## 1.2、查看PV
```bash
# 查看pv
$ kubectl get pv
NAME          CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM   STORAGECLASS    REASON   AGE
nfs-pv001     20Gi       RWO            Recycle          Available           nfs                      68s
nfs-pv002     30Gi       RWO            Recycle          Available           nfs                      33s

#STATUS 为 Available，表示 pv 就绪，可以被 PVC 申请。
```

# 二、PVC资源申请

## 2.1、pvc配置

接下来创建2个名为pvc001和pvc002的PVC，配置文件 nfs-pvc001.yaml 如下：

1、nfs-pvc001.yaml

```bash
# 清理pvc资源
kubectl delete -f nfs-pvc001.yaml

# 编写pvc资源文件
cat > nfs-pvc001.yaml <<\EOF           
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs-pvc001
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
  storageClassName: nfs
  selector:
    matchLabels:
      pv: nfs-pv001
EOF

# 部署pvc到集群中
kubectl apply -f nfs-pvc001.yaml
```

2、nfs-pvc002.yaml
```bash
# 清理pvc资源
kubectl delete -f nfs-pvc002.yaml

# 编写pvc资源文件
cat > nfs-pvc002.yaml <<\EOF           
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs-pvc002
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 30Gi
  storageClassName: nfs
  selector:
    matchLabels:
      pv: nfs-pv002
EOF

# 部署pvc到集群中
kubectl apply -f nfs-pvc002.yaml
```

## 2.2、查看PVC/PV
```bash
$ kubectl get pvc
NAME            STATUS   VOLUME          CAPACITY   ACCESS MODES   STORAGECLASS   AGE
nfs-pvc001      Bound    nfs-pv001       20Gi       RWO            nfs            18s
nfs-pvc002      Bound    nfs-pv002       30Gi       RWO            nfs            7s

$ kubectl get pv
NAME          CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                STORAGECLASS   REASON   AGE
nfs-pv001     20Gi       RWO            Recycle          Bound    default/nfs-pvc001   nfs                     17m
nfs-pv002     30Gi       RWO            Recycle          Bound    default/nfs-pvc002   nfs                     17m

# 从 kubectl get pvc 和 kubectl get pv 的输出可以看到 pvc001 和pvc002分别绑定到pv001和pv002，申请成功。注意pvc绑定到对应pv通过labels标签方式实现，也可以不指定，将随机绑定到pv。
```

# 三、Pod 中使用存储

```bash
# 与使用普通 Volume 的格式类似，在 volumes 中通过 persistentVolumeClaim 指定使用nfs-pvc001和nfs-pvc002申请的 Volume。
```

1、nfs-pod001.yaml 

```bash
# 清理pod资源
kubectl delete -f nfs-pod001.yaml

# 编写pod资源文件
cat > nfs-pod001.yaml <<\EOF
kind: Pod
apiVersion: v1
metadata:
  name: nfs-pod001
spec:
  containers:
    - name: myfrontend
      image: nginx
      volumeMounts:
      - mountPath: "/var/www/html"
        name: nfs-pv001
  volumes:
    - name: nfs-pv001
      persistentVolumeClaim:
        claimName: nfs-pvc001
EOF

# 创建pod资源
kubectl apply -f nfs-pod001.yaml

```

2、nfs-pod002.yaml
```bash
# 清理pod资源
kubectl delete -f nfs-pod002.yaml

# 编写pod资源文件
cat > nfs-pod002.yaml <<\EOF
kind: Pod
apiVersion: v1
metadata:
  name: nfs-pod002
spec:
  containers:
    - name: myfrontend
      image: nginx
      volumeMounts:
      - mountPath: "/var/www/html"
        name: nfs-pv002
  volumes:
    - name: nfs-pv002
      persistentVolumeClaim:
        claimName: nfs-pvc002
EOF

# 创建pod资源
kubectl apply -f nfs-pod002.yaml
```

参考资料：

https://blog.csdn.net/networken/article/details/86697018  kubernetes部署NFS持久存储
