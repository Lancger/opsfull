# Kubernetes CoreDNS

k8s集群内部服务发现是通过dns来实现的，其他pod之间的域名解析服务都是靠dns来实现的，目前支持2种dns，一种kubedns,一种coredns.

## 创建CoreDNS
```
[root@linux-node1 ~]# kubectl create -f /srv/addons/coredns/coredns.yaml 

[root@linux-node1 ~]# kubectl get pod -n kube-system
NAME                                    READY     STATUS    RESTARTS   AGE
coredns-77c989547b-9pj8b                1/1       Running   0          6m
coredns-77c989547b-kncd5                1/1       Running   0          6m
```
