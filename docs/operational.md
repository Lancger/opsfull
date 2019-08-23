
## 一、服务重启
```
#master
systemctl restart kube-scheduler
systemctl restart kube-controller-manager
systemctl restart kube-apiserver
systemctl restart flannel
systemctl restart etcd

systemctl stop kube-scheduler
systemctl stop kube-controller-manager
systemctl stop kube-apiserver
systemctl stop flannel
systemctl stop etcd

systemctl status kube-apiserver
systemctl status kube-scheduler
systemctl status kube-controller-manager
systemctl status etcd

#node
systemctl restart kubelet
systemctl restart kube-proxy
systemctl restart flannel
systemctl restart etcd

systemctl stop kubelet
systemctl stop kube-proxy
systemctl stop flannel
systemctl stop etcd

systemctl status kubelet
systemctl status kube-proxy
systemctl status flannel
systemctl status etcd
```

## 二、常用查询
```
#查询命名空间
[root@linux-node1 ~]# kubectl get namespace --all-namespaces
NAME              STATUS   AGE
default           Active   3d13h
kube-node-lease   Active   3d13h
kube-public       Active   3d13h
kube-system       Active   3d13h

#查询健康状况
[root@linux-node1 ~]# kubectl get cs --all-namespaces
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

#创建测试deployment
[root@linux-node1 ~]# kubectl run net-test --image=alpine --replicas=2 sleep 360000

#查看创建的deployment
kubectl get deployment -o wide --all-namespaces

#查询pod
[root@linux-node1 ~]# kubectl get pod -o wide --all-namespaces
NAME                        READY     STATUS    RESTARTS   AGE       IP          NODE
net-test-5767cb94df-6smfk   1/1       Running   1          1h        10.2.69.3   192.168.56.12
net-test-5767cb94df-ctkhz   1/1       Running   1          1h        10.2.17.3   192.168.56.13

#查询service
[root@linux-node1 ~]# kubectl get service
NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   10.1.0.1     <none>        443/TCP   4m

#Etcd集群健康状况查询
[root@linux-node1 ~]# etcdctl --endpoints=https://192.168.56.11:2379 \
  --ca-file=/opt/kubernetes/ssl/ca.pem \
  --cert-file=/opt/kubernetes/ssl/etcd.pem \
  --key-file=/opt/kubernetes/ssl/etcd-key.pem cluster-health
```

## 三、修改POD的IP地址段
```
#修改一
[root@linux-node1 ~]# vim /usr/lib/systemd/system/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/opt/kubernetes/bin/kube-controller-manager \
  --address=127.0.0.1 \
  --master=http://127.0.0.1:8080 \
  --allocate-node-cidrs=true \
  --service-cluster-ip-range=10.1.0.0/16 \
  --cluster-cidr=10.2.0.0/16 \          ---POD的IP地址段
  --cluster-name=kubernetes \
  --cluster-signing-cert-file=/opt/kubernetes/ssl/ca.pem \
  --cluster-signing-key-file=/opt/kubernetes/ssl/ca-key.pem \
  --service-account-private-key-file=/opt/kubernetes/ssl/ca-key.pem \
  --root-ca-file=/opt/kubernetes/ssl/ca.pem \
  --leader-elect=true \
  --v=2 \
  --logtostderr=false \
  --log-dir=/opt/kubernetes/log

Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target

#修改二（修改etcd key中的值）

#创建etcd的key值
/opt/kubernetes/bin/etcdctl --ca-file /opt/kubernetes/ssl/ca.pem --cert-file /opt/kubernetes/ssl/flanneld.pem --key-file /opt/kubernetes/ssl/flanneld-key.pem \
      --no-sync -C https://192.168.56.11:2379,https://192.168.56.12:2379,https://192.168.56.13:2379 \
mk /kubernetes/network/config '{ "Network": "10.2.0.0/16", "Backend": { "Type": "vxlan", "VNI": 1 }}'

获取etcd中key的值
/opt/kubernetes/bin/etcdctl --ca-file /opt/kubernetes/ssl/ca.pem --cert-file /opt/kubernetes/ssl/flanneld.pem --key-file /opt/kubernetes/ssl/flanneld-key.pem \
      --no-sync -C https://192.168.56.11:2379,https://192.168.56.12:2379,https://192.168.56.13:2379 \
get /kubernetes/network/config

修改etcd中key的值  
/opt/kubernetes/bin/etcdctl --ca-file /opt/kubernetes/ssl/ca.pem --cert-file /opt/kubernetes/ssl/flanneld.pem --key-file /opt/kubernetes/ssl/flanneld-key.pem \
      --no-sync -C https://192.168.56.11:2379,https://192.168.56.12:2379,https://192.168.56.13:2379 \
set /kubernetes/network/config '{ "Network": "10.3.0.0/16", "Backend": { "Type": "vxlan", "VNI": 1 }}'
```

