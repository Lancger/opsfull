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
