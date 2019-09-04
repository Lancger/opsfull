kubeadm 是kubernetes 的集群安装工具，能够快速安装kubernetes 集群。

kubeadm init 命令默认使用的docker镜像仓库为k8s.gcr.io，国内无法直接访问，于是需要变通一下。

1、首先查看需要使用哪些镜像
```
kubeadm config images list
#输出如下结果

k8s.gcr.io/kube-apiserver:v1.15.3
k8s.gcr.io/kube-controller-manager:v1.15.3
k8s.gcr.io/kube-scheduler:v1.15.3
k8s.gcr.io/kube-proxy:v1.15.3
k8s.gcr.io/pause:3.1
k8s.gcr.io/etcd:3.3.10
k8s.gcr.io/coredns:1.3.1
```

参考文档：

https://cloud.tencent.com/info/6db42438f5dd7842bcecb6baf61833aa.html  kubeadm 无法下载镜像问题

https://juejin.im/post/5b8a4536e51d4538c545645c  使用kubeadm 部署 Kubernetes(国内环境)
