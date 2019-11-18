# 一、K8S攻略
- [Kubernetes架构介绍](docs/Kubernetes架构介绍.md)
- [Kubernetes集群环境准备](docs/Kubernetes集群环境准备.md)
- [Docker安装](docs/docker-install.md)
- [CA证书制作](docs/ca.md)
- [ETCD集群部署](docs/etcd-install.md)
- [Master节点部署](docs/master.md)
- [Node节点部署](docs/node.md)
- [Flannel部署](docs/flannel.md)
- [应用创建](docs/app.md)
- [问题汇总](docs/k8s-error-resolution.md)
- [常用手册](docs/operational.md)
- [Envoy 的架构与基本术语](docs/Envoy的架构与基本术语.md)
- [K8S学习手册](docs/Kubernetes学习笔记.md)
- [K8S重启pod](docs/k8s%E9%87%8D%E5%90%AFpod.md)
- [K8S清理](docs/delete.md)
- [外部访问K8s中Pod的几种方式](docs/外部访问K8s中Pod的几种方式.md)
- [应用测试](docs/app2.md)
- [PVC](docs/k8s_pv_local.md)
- [dashboard操作](docs/dashboard_op.md)


# 使用手册
<table border="0">
    <tr>
        <td><strong>手动部署</strong></td>
        <td><a href="docs/Kubernetes集群环境准备.md">1.Kubernetes集群环境准备</a></td>
        <td><a href="docs/docker-install.md">2.Docker安装</a></td>
        <td><a href="docs/ca.md">3.CA证书制作</a></td>
        <td><a href="docs/etcd-install.md">4.ETCD集群部署</a></td>
        <td><a href="docs/master.md">5.Master节点部署</a></td>
        <td><a href="docs/node.md">6.Node节点部署</a></td>
        <td><a href="docs/flannel.md">7.Flannel部署</a></td>
        <td><a href="docs/app.md">8.应用创建</a></td>
    </tr>
    <tr>
        <td><strong>必备插件</strong></td>
        <td><a href="docs/coredns.md">1.CoreDNS部署</a></td>
        <td><a href="docs/dashboard.md">2.Dashboard部署</a></td>
        <td><a href="docs/heapster.md">3.Heapster部署</a></td>
        <td><a href="docs/ingress.md">4.Ingress部署</a></td>
        <td><a href="https://github.com/unixhot/devops-x">5.CI/CD</a></td>
        <td><a href="docs/helm.md">6.Helm部署</a></td>
        <td><a href="docs/helm.md">6.Helm部署</a></td>
    </tr>
</table>

# 二、k8s资源清理
```
1、# svc清理
$ kubectl delete svc $(kubectl get svc -n mos-namespace|grep -v NAME|awk '{print $1}') -n mos-namespace
service "mysql-production" deleted
service "nginx-test" deleted
service "redis-cluster" deleted
service "redis-production" deleted

2、# deployment清理
$ kubectl delete deployment $(kubectl get deployment -n mos-namespace|grep -v NAME|awk '{print $1}') -n mos-namespace
deployment.extensions "centos7-app" deleted

3、# configmap清理
$ kubectl delete cm $(kubectl get cm -n mos-namespace|grep -v NAME|awk '{print $1}') -n mos-namespace
```
