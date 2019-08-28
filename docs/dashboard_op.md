# Kubernetes Dashboard

## 查看deployment
```
[root@node1 ~]# kubectl get deployment -A
NAMESPACE     NAME                         READY   UP-TO-DATE   AVAILABLE   AGE
default       my-mc-deployment             3/3     3            3           2d18h
default       net                          3/3     3            3           4d15h
default       net-test                     2/2     2            2           4d16h
default       test-hello                   1/1     1            1           6d
default       test-jrr                     1/1     1            1           43h
kube-system   coredns                      0/2     2            0           4d15h
kube-system   heapster                     1/1     1            1           8d
kube-system   kubernetes-dashboard         0/1     1            0           4m42s
kube-system   metrics-server               0/1     1            0           8d
kube-system   traefik-ingress-controller   1/1     1            1           2d18h
```
## 查看Dashboard信息
```
#发现Dashboard是运行在node3节点
[root@linux-node1 ~]# kubectl get pod -n kube-system -o wide
NAME                                    READY     STATUS    RESTARTS   AGE       IP          NODE
kubernetes-dashboard-66c9d98865-bqwl5   1/1       Running   0          1h        10.2.76.3   192.168.56.13

#查看Dashboard运行日志
[root@linux-node1 ~]# kubectl logs pod/kubernetes-dashboard-66c9d98865-bqwl5 -n kube-system

#查看Dashboard服务IP(可以访问任意node节点的34696端口就可以访问到Dashboard页面 https://192.168.56.13:34696/#!/overview?namespace=default,如何master节点安装了kube-proxy也可以访问)
[root@linux-node1 ~]# kubectl get service -n kube-system
NAME                   TYPE       CLUSTER-IP   EXTERNAL-IP   PORT(S)         AGE
kubernetes-dashboard   NodePort   10.1.36.42   <none>        443:34696/TCP   1h

```
https://192.168.56.13:34696/#!/overview?namespace=default

  ![dashboard登录](https://github.com/Lancger/opsfull/blob/master/images/Dashboard-login.jpg)


## 访问Dashboard

https://192.168.56.11:6443/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy
用户名:admin  密码：admin 选择令牌模式登录。

### 获取Token
```
[root@linux-node1 ~]# kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep admin-user | awk '{print $1}')
Name:         admin-user-token-c97bl
Namespace:    kube-system
Labels:       <none>
Annotations:  kubernetes.io/service-account.name=admin-user
              kubernetes.io/service-account.uid=379208ff-cb86-11e8-9f1c-080027dc9cd8

Type:  kubernetes.io/service-account-token

Data
====
ca.crt:     1359 bytes
namespace:  11 bytes
token:      eyJhbGciOiJSUzI1NiIsImtpZCI6IiJ9.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJrdWJlLXN5c3RlbSIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJhZG1pbi11c2VyLXRva2VuLWM5N2JsIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZXJ2aWNlLWFjY291bnQubmFtZSI6ImFkbWluLXVzZXIiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC51aWQiOiIzNzkyMDhmZi1jYjg2LTExZTgtOWYxYy0wODAwMjdkYzljZDgiLCJzdWIiOiJzeXN0ZW06c2VydmljZWFjY291bnQ6a3ViZS1zeXN0ZW06YWRtaW4tdXNlciJ9.LopL7AD9feBZmhAuAUlPNjfthlJ1lJAPG6VXgBl-MZdofZpqNU9m-o-7M4hHa5AXkpeLvQrA1UKWWSR9eWEN06ugIkcH4Pk-tKrSVQUM6CDaE7eBdK91x1ltTonLz62_z_X8IvRYx1piv3wRUijoyRHCdziBnOhg67sT974CSPoRSOpl7ZR0Kn_L0LYRMOE9xfU3w4-sCpSx-jgc5oysAix95NqZgIkaZ6TRANpCnHE66fqL6yUwQxQ5yt7pw7J2iuSE3OxPU_cKArjYlWUvr72zG3SxZaR7dzQEggwmjSSeHRs0OK0968QAtCca1NTmcPaTtKhXYfXXdtusVCx7bA
```
  ![dashboard预览](https://github.com/Lancger/opsfull/blob/master/images/Dashboard.jpg)
