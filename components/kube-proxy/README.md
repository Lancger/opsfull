# Kube-Proxy简述

```
运行在每个节点上，监听 API Server 中服务对象的变化，再通过管理 IPtables 来实现网络的转发
Kube-Proxy 目前支持三种模式：

UserSpace
    k8s v1.2 后就已经淘汰

IPtables
    目前默认方式

IPVS
    需要安装ipvsadm、ipset 工具包和加载 ip_vs 内核模块

```
参考资料：

https://ywnz.com/linuxyffq/2530.html  解析从外部访问Kubernetes集群中应用的几种方法  

https://www.jianshu.com/p/b2d13cec7091  浅谈 k8s service&kube-proxy  

https://www.codercto.com/a/90806.html  探究K8S Service内部iptables路由规则

https://blog.51cto.com/goome/2369150  k8s实践7:ipvs结合iptables使用过程分析
