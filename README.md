# Kubernetes架构介绍

## Kubernetes架构

![](https://github.com/Lancger/opsfull/blob/master/images/kubernetes%E6%9E%B6%E6%9E%84.jpg)

## k8s架构图

![](https://github.com/Lancger/opsfull/blob/master/images/k8s%E6%9E%B6%E6%9E%84%E5%9B%BE.jpg)

## K8S Master节点
### API Server
1. 供Kubernetes API接口，主要处理 REST操作以及更新ETCD中的对象。 所有资源增删改查的唯一入口。
### Scheduler
2. 资源调度，负责Pod到Node的调度。
### Controller Manager
3. 所有其他群集级别的功能，目前由控制器Manager执行。资源对象的
自动化控制中心。
### ETCD
4. 所有持久化的状态信息存储在ETCD中。
## K8S Node节点
### Kubelet
1. 管理Pods以及容器、镜像、Volume等，实现对集群 对节点的管理。
### Kube-proxy
2. 提供网络代理以及负载均衡，实现与Service通信。
### Docker Engine
3. 负责节点的容器的管理工作。
