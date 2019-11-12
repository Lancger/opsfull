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
