# 报错一：flanneld 启动不了
```
Oct 10 10:42:19 linux-node3 flanneld: E1010 10:42:19.499080    1816 main.go:349] Couldn't fetch network config: 100: Key not found (/coreos.com) [11]
```
# 解决办法：
```
/opt/kubernetes/bin/etcdctl --ca-file /opt/kubernetes/ssl/ca.pem \
    --cert-file /opt/kubernetes/ssl/flanneld.pem \
    --key-file /opt/kubernetes/ssl/flanneld-key.pem \
    --no-sync -C https://192.168.56.11:2379,https://192.168.56.12:2379,https://192.168.56.13:2379 \
    mk /coreos.com/network/config '{"Network":"172.17.0.0/16"}'
```
