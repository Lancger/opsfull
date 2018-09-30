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

### 3.1 Replication Controller，RC

RC是K8s集群中最早的保证Pod高可用的API对象。通过监控运行中
的Pod来保证集群中运行指定数目的Pod副本。

指定的数目可以是多个也可以是1个;少于指定数目，RC就会启动运
行新的Pod副本;多于指定数目，RC就会杀死多余的Pod副本。

即使在指定数目为1的情况下，通过RC运行Pod也比直接运行Pod更 明智，因为RC也可以发挥它高可用的能力，保证永远有1个Pod在运 行。

### 3.2 Replica Set，RS

RS是新一代RC，提供同样的高可用能力，区别主要在于RS后来居上， 能支持更多中的匹配模式。副本集对象一般不单独使用，而是作为部 署的理想状态参数使用。

是K8S 1.2中出现的概念，是RC的升级。一般和Deployment共同使用。

### 3.3 Deployment
Deployment表示用户对K8s集群的一次更新操作。Deployment是 一个比RS应用模式更广的API对象，

可以是创建一个新的服务，更新一个新的服务，也可以是滚动升 级一个服务。滚动升级一个服务，实际是创建一个新的RS，然后 逐渐将新RS中副本数增加到理想状态，将旧RS中的副本数减小 到0的复合操作;

这样一个复合操作用一个RS是不太好描述的，所以用一个更通用 的Deployment来描述。

### 3.4 Service
RC、RS和Deployment只是保证了支撑服务的POD的数量，但是没有解 决如何访问这些服务的问题。一个Pod只是一个运行服务的实例，随时可 能在一个节点上停止，在另一个节点以一个新的IP启动一个新的Pod，因 此不能以确定的IP和端口号提供服务。

要稳定地提供服务需要服务发现和负载均衡能力。服务发现完成的工作， 是针对客户端访问的服务，找到对应的的后端服务实例。

在K8集群中，客户端需要访问的服务就是Service对象。每个Service会对 应一个集群内部有效的虚拟IP，集群内部通过虚拟IP访问一个服务。

## 四、K8S的IP地址
Node IP: 节点设备的IP，如物理机，虚拟机等容器宿主的实际IP。 

Pod IP: Pod 的IP地址，是根据docker0网格IP段进行分配的。 

Cluster IP: Service的IP，是一个虚拟IP，仅作用于service对象，由k8s
管理和分配，需要结合service port才能使用，单独的IP没有通信功能，
集群外访问需要一些修改。

在K8S集群内部，nodeip podip clusterip的通信机制是由k8s制定的路由
规则，不是IP路由。
