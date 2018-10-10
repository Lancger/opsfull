## 报错一：flanneld 启动不了
```
Oct 10 10:42:19 linux-node1 flanneld: E1010 10:42:19.499080    1816 main.go:349] Couldn't fetch network config: 100: Key not found (/coreos.com) [11]
```
## 解决办法：
```
#首先查看flannel使用的那种类型的网络模式是对应的etcd中的key是哪个（/kubernetes/network/config 或 /coreos.com/network ）
[root@linux-node3 cfg]# cat /opt/kubernetes/cfg/flannel
FLANNEL_ETCD="-etcd-endpoints=https://192.168.56.11:2379,https://192.168.56.12:2379,https://192.168.56.13:2379"
FLANNEL_ETCD_KEY="-etcd-prefix=/coreos.com/network"   ----这个参数值
FLANNEL_ETCD_CAFILE="--etcd-cafile=/opt/kubernetes/ssl/ca.pem"
FLANNEL_ETCD_CERTFILE="--etcd-certfile=/opt/kubernetes/ssl/flanneld.pem"
FLANNEL_ETCD_KEYFILE="--etcd-keyfile=/opt/kubernetes/ssl/flanneld-key.pem"

#etcd集群集群执行下面命令，清空etcd数据
rm -rf /var/lib/etcd/default.etcd/

#下面这条只需在一个节点执行就可以
#如果是/coreos.com/network则执行下面的
[root@linux-node1 ~]# /opt/kubernetes/bin/etcdctl --ca-file /opt/kubernetes/ssl/ca.pem \
    --cert-file /opt/kubernetes/ssl/flanneld.pem \
    --key-file /opt/kubernetes/ssl/flanneld-key.pem \
    --no-sync -C https://192.168.56.11:2379,https://192.168.56.12:2379,https://192.168.56.13:2379 \
    mk /coreos.com/network/config '{"Network":"172.17.0.0/16"}'

#如果是/kubernetes/network/config则执行下面的
[root@linux-node1 ~]# /opt/kubernetes/bin/etcdctl --ca-file /opt/kubernetes/ssl/ca.pem \
    --cert-file /opt/kubernetes/ssl/flanneld.pem \
    --key-file /opt/kubernetes/ssl/flanneld-key.pem \
    --no-sync -C https://192.168.56.11:2379,https://192.168.56.12:2379,https://192.168.56.13:2379 \
    mk /kubernetes/network/config '{ "Network": "10.2.0.0/16", "Backend": { "Type": "vxlan", "VNI": 1 }}'
```
参考文档：https://stackoverflow.com/questions/34439659/flannel-and-docker-dont-start

## 报错二：
```
Oct 10 11:40:11 linux-node1 flanneld: E1010 11:40:11.797324   20669 main.go:349] Couldn't fetch network config: 104: Not a directory (/kubernetes/network/config) [12]

问题原因：在初次配置的时候，把flannel的配置文件中的etcd-prefix-key配置成了/kubernetes/network/config，实际上应该是/kubernetes/network

[root@linux-node1 ~]# cat /opt/kubernetes/cfg/flannel
FLANNEL_ETCD="-etcd-endpoints=https://192.168.56.11:2379,https://192.168.56.12:2379,https://192.168.56.13:2379"
FLANNEL_ETCD_KEY="-etcd-prefix=/kubernetes/network/config"    --正确的应该为 /kubernetes/network/
FLANNEL_ETCD_CAFILE="--etcd-cafile=/opt/kubernetes/ssl/ca.pem"
FLANNEL_ETCD_CERTFILE="--etcd-certfile=/opt/kubernetes/ssl/flanneld.pem"
FLANNEL_ETCD_KEYFILE="--etcd-keyfile=/opt/kubernetes/ssl/flanneld-key.pem"

```
参考文档：https://www.cnblogs.com/lyzw/p/6016789.html
