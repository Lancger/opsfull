作为准备工作，我们已经在 k8s同一局域内网节点上搭建了一个 NFS 服务器，目录为 /data/nfs

# 一、静态申请PV卷

nfs-server上操作，添加pv卷对应目录,这里创建2个pv卷，则添加2个pv卷的目录作为挂载点。

```bash
#创建pv卷对应的目录
mkdir -p /data/nfs/pv001
mkdir -p /data/nfs/pv002

#配置exportrs
$ vim /etc/exports
/data/nfs *(rw,no_root_squash,sync)
/data/nfs/pv001 *(rw,no_root_squash,sync)
/data/nfs/pv002 *(rw,no_root_squash,sync)

#配置生效
exportfs -r

#重启rpcbind、nfs服务
systemctl restart rpcbind && systemctl restart nfs

#查看挂载点
$ exportfs
/data/nfs        <world>
/data/nfs/pv001  <world>
/data/nfs/pv002  <world>
```

# 二、创建PV

下面创建2个名为pv001和pv002的PV卷，配置文件 nfs-pv001.yaml 如下

```bash
# 清理pv资源
kubectl delete -f mysql-static-pv.yaml

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

# 查看pv
kubectl get pv
```
