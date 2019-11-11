# 一、MySQL持久化演练

数据库提供持久化存储，主要分为下面几个步骤：

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

1、创建 PV 和 PVC

```bash
kubectl delete -f mysql-static-pv.yaml

cat > mysql-static-pv.yaml <<\EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mysql-static-pv
spec:
  capacity:
    storage: 10Gi

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
    path: /nfs/data/
    server: 10.198.1.156
  mountOptions:
    - vers=4
    - minorversion=0
    - noresvport
EOF

kubectl apply -f mysql-static-pv.yaml
```

参考文档：

https://blog.51cto.com/wzlinux/2330295   Kubernetes 之 MySQL 持久存储和故障转移(十一)

https://qingmu.io/2019/08/11/Run-mysql-on-kubernetes/ 从部署mysql聊一聊有状态服务和PV及PVC
