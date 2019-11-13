# 一、MySQL持久化演练

## 1、数据库提供持久化存储，主要分为下面几个步骤：

    1、创建 PV 和 PVC

    2、部署 MySQL

    3、向 MySQL 添加数据

    4、模拟节点宕机故障，Kubernetes 将 MySQL 自动迁移到其他节点

    5、验证数据一致性
   

# 二、静态PV PVC

```bash
PV就好比是一个仓库，我们需要先购买一个仓库，即定义一个PV存储服务，例如CEPH,NFS,Local Hostpath等等。

PVC就好比租户，pv和pvc是一对一绑定的，挂载到POD中，一个pvc可以被多个pod挂载。
```

## 1、创建 PV

```bash
# 清理pv资源
kubectl delete -f mysql-static-pv.yaml

# 编写pv yaml资源文件
cat > mysql-static-pv.yaml <<\EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mysql-static-pv
spec:
  capacity:
    storage: 80Gi

  accessModes:
    - ReadWriteOnce
  #ReadWriteOnce - 卷可以由单个节点以读写方式挂载
  #ReadOnlyMany  - 卷可以由许多节点以只读方式挂载
  #ReadWriteMany - 卷可以由许多节点以读写方式挂载

  persistentVolumeReclaimPolicy: Retain
  #Retain，不清理, 保留 Volume（需要手动清理）
  #Recycle，删除数据，即 rm -rf /thevolume/*（只有 NFS 和 HostPath 支持）
  #Delete，删除存储资源，比如删除 AWS EBS 卷（只有 AWS EBS, GCE PD, Azure Disk 和 Cinder 支持）

  nfs:
    path: /data/nfs/
    server: 10.198.1.156
  mountOptions:
    - vers=4
    - minorversion=0
    - noresvport
EOF

# 部署pv到集群中
kubectl apply -f mysql-static-pv.yaml

# 查看pv
$ kubectl get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM                                           STORAGECLASS          REASON   AGE
mysql-static-pv                            80Gi       RWO            Retain           Available                                                                                  4m20s
```

## 2、创建PVC

```bash
# 清理pvc资源
kubectl delete -f mysql-pvc.yaml 

# 编写pvc yaml资源文件
cat > mysql-pvc.yaml <<\EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-static-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 80Gi
EOF

# 创建pvc资源
kubectl apply -f mysql-pvc.yaml

# 查看pvc
$ kubectl get pvc
NAME               STATUS        VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
mysql-static-pvc   Bound         pvc-c55f8695-2a0b-4127-a60b-5c1aba8b9104   80Gi       RWO            nfs-storage    81s
```

# 三、部署 MySQL

MySQL 的配置文件mysql.yaml如下：

```bash
kubectl delete -f mysql.yaml

cat >mysql.yaml<<\EOF
apiVersion: v1
kind: Service
metadata:
  name: mysql
spec:
  ports:
  - port: 3306
  selector:
    app: mysql
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: mysql
spec:
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:5.6
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: password
        ports:
        - name: mysql
          containerPort: 3306
        volumeMounts:
        - name: mysql-persistent-storage
          mountPath: /var/lib/mysql
      volumes:
      - name: mysql-persistent-storage
        persistentVolumeClaim:
          claimName: mysql-static-pvc
EOF

kubectl apply -f mysql.yaml

PVC mysql-static-pvc Bound 的 PV mysql-static-pv 将被 mount 到 MySQL 的数据目录 /var/lib/mysql。
```

参考文档：

https://blog.51cto.com/wzlinux/2330295   Kubernetes 之 MySQL 持久存储和故障转移(十一)

https://qingmu.io/2019/08/11/Run-mysql-on-kubernetes/ 从部署mysql聊一聊有状态服务和PV及PVC
