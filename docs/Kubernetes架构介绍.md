# Kubernetes架构介绍

## Kubernetes架构

![](https://github.com/Lancger/opsfull/blob/master/images/kubernetes%E6%9E%B6%E6%9E%84.jpg)

## k8s架构图

![](https://github.com/Lancger/opsfull/blob/master/images/k8s%E6%9E%B6%E6%9E%84%E5%9B%BE.jpg)

## 一、K8S Master节点
### API Server
apiserver提供集群管理的REST API接口，包括认证授权、数据校验以 及集群状态变更等
只有API Server才直接操作etcd
其他模块通过API Server查询或修改数据
提供其他模块之间的数据交互和通信的枢纽

### Scheduler
scheduler负责分配调度Pod到集群内的node节点
监听kube-apiserver，查询还未分配Node的Pod
根据调度策略为这些Pod分配节点

### Controller Manager
controller-manager由一系列的控制器组成，它通过apiserver监控整个 集群的状态，并确保集群处于预期的工作状态

### ETCD
所有持久化的状态信息存储在ETCD中

## 二、K8S Node节点
### Kubelet
1. 管理Pods以及容器、镜像、Volume等，实现对集群 对节点的管理。
### Kube-proxy
2. 提供网络代理以及负载均衡，实现与Service通信。
### Docker Engine
3. 负责节点的容器的管理工作。

## 三、资源对象介绍

### Replication Controller，RC

 RC是K8s集群中最早的保证Pod高可用的API对象。通过监控运行中
的Pod来保证集群中运行指定数目的Pod副本。

 指定的数目可以是多个也可以是1个;少于指定数目，RC就会启动运
行新的Pod副本;多于指定数目，RC就会杀死多余的Pod副本。

 即使在指定数目为1的情况下，通过RC运行Pod也比直接运行Pod更 明智，因为RC也可以发挥它高可用的能力，保证永远有1个Pod在运 行。
