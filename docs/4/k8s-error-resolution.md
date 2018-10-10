## 报错一：flanneld 启动不了
```
Oct 10 10:42:19 linux-node1 flanneld: E1010 10:42:19.499080    1816 main.go:349] Couldn't fetch network config: 100: Key not found (/coreos.com) [11]
```
## 解决办法：
```
#etcd集群集群执行下面命令，清空etcd数据
rm -rf /var/lib/etcd/default.etcd/

#下面这条只需在一个节点执行就可以
[root@linux-node1 ~]# /opt/kubernetes/bin/etcdctl --ca-file /opt/kubernetes/ssl/ca.pem \
    --cert-file /opt/kubernetes/ssl/flanneld.pem \
    --key-file /opt/kubernetes/ssl/flanneld-key.pem \
    --no-sync -C https://192.168.56.11:2379,https://192.168.56.12:2379,https://192.168.56.13:2379 \
    mk /coreos.com/network/config '{"Network":"172.17.0.0/16"}'

[root@linux-node1 ~]# /opt/kubernetes/bin/etcdctl --ca-file /opt/kubernetes/ssl/ca.pem \
    --cert-file /opt/kubernetes/ssl/flanneld.pem \
    --key-file /opt/kubernetes/ssl/flanneld-key.pem \
    --no-sync -C https://192.168.56.11:2379,https://192.168.56.12:2379,https://192.168.56.13:2379 \
    mk /kubernetes/network/config '{ "Network": "10.2.0.0/16", "Backend": { "Type": "vxlan", "VNI": 1 }}'
```
参考文档：https://stackoverflow.com/questions/34439659/flannel-and-docker-dont-start
