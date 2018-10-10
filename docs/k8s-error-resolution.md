## 一、服务重启
```
#master
systemctl restart kube-scheduler
systemctl restart kube-controller-manager
systemctl restart kube-apiserver
systemctl restart flanneld
systemctl restart etcd

systemctl stop kube-scheduler
systemctl stop kube-controller-manager
systemctl stop kube-apiserver
systemctl stop flanneld
systemctl stop etcd

systemctl status kube-apiserver
systemctl status kube-scheduler
systemctl status kube-controller-manager
systemctl status etcd

#node
systemctl restart kubelet
systemctl restart kube-proxy
systemctl restart flanneld
systemctl restart etcd

systemctl stop kubelet
systemctl stop kube-proxy
systemctl stop flanneld
systemctl stop etcd

systemctl status kubelet
systemctl status kube-proxy
systemctl status flanneld
systemctl status etcd

#查询健康状况
[root@linux-node1 ~]# kubectl get cs
NAME                 STATUS    MESSAGE             ERROR
controller-manager   Healthy   ok
scheduler            Healthy   ok
etcd-0               Healthy   {"health":"true"}
etcd-2               Healthy   {"health":"true"}
etcd-1               Healthy   {"health":"true"}

#查询node
[root@linux-node1 ~]# kubectl get node -o wide
NAME            STATUS    ROLES     AGE       VERSION   EXTERNAL-IP   OS-IMAGE                KERNEL-VERSION          CONTAINER-RUNTIME
192.168.56.12   Ready     <none>    2m        v1.10.3   <none>        CentOS Linux 7 (Core)   3.10.0-862.el7.x86_64   docker://18.6.1
192.168.56.13   Ready     <none>    2m        v1.10.3   <none>        CentOS Linux 7 (Core)   3.10.0-862.el7.x86_64   docker://18.6.1

#查询pod
[root@linux-node1 ~]# kubectl get pod -o wide
NAME                        READY     STATUS    RESTARTS   AGE       IP          NODE
net-test-5767cb94df-6smfk   1/1       Running   1          1h        10.2.69.3   192.168.56.12
net-test-5767cb94df-ctkhz   1/1       Running   1          1h        10.2.17.3   192.168.56.13

#查询service
[root@linux-node1 ~]# kubectl get service
NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   10.1.0.1     <none>        443/TCP   4m
```
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
