作为准备工作，我们已经在 k8s同一局域内网节点上搭建了一个 NFS 服务器，目录为 /data/nfs

# 一、静态申请PV卷

nfs-server上操作，添加pv卷对应目录,这里创建2个pv卷，则添加2个pv卷的目录作为挂载点。

```bash
# 创建pv卷对应的目录
mkdir -p /data/nfs/pv001
mkdir -p /data/nfs/pv002

# 配置exportrs
$ vim /etc/exports
/data/nfs *(rw,no_root_squash,sync)
/data/nfs/pv001 *(rw,no_root_squash,sync)
/data/nfs/pv002 *(rw,no_root_squash,sync)

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

# 二、创建PV

下面创建2个名为pv001和pv002的PV卷，配置文件 nfs-pv001.yaml 如下

```bash
配置说明：

① capacity 指定 PV 的容量为 20G。

② accessModes 指定访问模式为 ReadWriteOnce，支持的访问模式有：
    ReadWriteOnce – PV 能以 read-write 模式 mount 到单个节点。
    ReadOnlyMany – PV 能以 read-only 模式 mount 到多个节点。
    ReadWriteMany – PV 能以 read-write 模式 mount 到多个节点。
    
③ persistentVolumeReclaimPolicy 指定当 PV 的回收策略为 Recycle，支持的策略有：
    Retain – 需要管理员手工回收。
    Recycle – 清除 PV 中的数据，效果相当于执行 rm -rf /thevolume/*。
    Delete – 删除 Storage Provider 上的对应存储资源，例如 AWS EBS、GCE PD、AzureDisk、OpenStack Cinder Volume 等。
    
④ storageClassName 指定 PV 的 class 为 nfs。相当于为 PV 设置了一个分类，PVC 可以指定 class 申请相应 class 的 PV。

⑤ 指定 PV 在 NFS 服务器上对应的目录。
```

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
    path: /nfs/data/pv001
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
    path: /nfs/data/pv002
    server: 192.168.56.11
EOF

# 部署pv到集群中
kubectl apply -f nfs-pv002.yaml
```

# 三、查看PV
```bash
# 查看pv
kubectl get pv
NAME          CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM   STORAGECLASS    REASON   AGE
nfs-pv001     20Gi       RWO            Recycle          Available           nfs                      68s
nfs-pv002     30Gi       RWO            Recycle          Available           nfs                      33s

#STATUS 为 Available，表示 pv 就绪，可以被 PVC 申请。
```
