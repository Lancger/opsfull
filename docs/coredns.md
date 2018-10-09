# Kubernetes CoreDNS

k8s集群内部服务发现是通过dns来实现的，其他pod之间的域名解析服务都是靠dns来实现的，目前支持2种dns，一种kubedns,一种coredns.

## 创建CoreDNS

```
#将本项目clone到/opt/目录

[root@linux-node1 ~]# kubectl create -f /opt/opsfull/example/coredns/coredns.yaml

[root@linux-node1 ~]# kubectl get pod -n kube-system    --k8s内部的服务默认放在kube-system单独的命名空间
NAME                                    READY     STATUS    RESTARTS   AGE
coredns-77c989547b-9pj8b                1/1       Running   0          6m
coredns-77c989547b-kncd5                1/1       Running   0          6m


#查看service
[root@linux-node1 ~]# kubectl get service -n kube-system
NAME                   TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)         AGE
coredns                ClusterIP   10.1.0.2     <none>        53/UDP,53/TCP   2m

#在node节点使用ipvsadm -Ln查看转发的后端节点（TCP和UDP的53端口）
[root@linux-node2 ~]# ipvsadm -Ln
IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  10.1.0.2:53 rr
  -> 10.2.76.14:53                Masq    1      0          0
  -> 10.2.76.20:53                Masq    1      0          0
UDP  10.1.0.2:53 rr
  -> 10.2.76.14:53                Masq    1      0          0
  -> 10.2.76.20:53                Masq    1      0          0
 
#发现是转到这2个pod容器
[root@linux-node1 ~]# kubectl get pod -n kube-system -o wide
NAME                                    READY     STATUS    RESTARTS   AGE       IP           NODE
coredns-77c989547b-4f9xz                1/1       Running   0          5m        10.2.76.20   192.168.56.12
coredns-77c989547b-9zm4m                1/1       Running   0          5m        10.2.76.14   192.168.56.13
```

## 测试CoreDNS

```
[root@linux-node1 ~]# kubectl run dns-test --rm -it --image=alpine /bin/sh

ping www.qq.com
```
