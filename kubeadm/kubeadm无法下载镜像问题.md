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

我们通过 docker.io/mirrorgooglecontainers 中转一下
```

2、批量下载及转换标签

脚本如下
```
#docker.io/mirrorgooglecontainers中转镜像

kubeadm config images list |sed -e 's/^/docker pull /g' -e 's#k8s.gcr.io#docker.io/mirrorgooglecontainers#g' |sh -x
docker images |grep mirrorgooglecontainers |awk '{print "docker tag ",$1":"$2,$1":"$2}' |sed -e 's#mirrorgooglecontainers#k8s.gcr.io#2' |sh -x
docker images |grep mirrorgooglecontainers |awk '{print "docker rmi ", $1":"$2}' |sh -x
docker pull coredns/coredns:1.3.1
docker tag coredns/coredns:1.3.1 k8s.gcr.io/coredns:1.3.1
docker rmi coredns/coredns:1.3.1

注：coredns没包含在docker.io/mirrorgooglecontainers中，需要手工从coredns官方镜像转换下。


#阿里云的镜像替换为谷歌的镜像

kubeadm config images list |sed -e 's/^/docker pull /g' -e 's#k8s.gcr.io#registry.cn-hangzhou.aliyuncs.com/google_containers#g' |sh -x
docker images |grep google_containers |awk '{print "docker tag ",$1":"$2,$1":"$2}' |sed -e 's#registry.cn-hangzhou.aliyuncs.com/google_containers#k8s.gcr.io#2' |sh -x
docker images |grep google_containers |awk '{print "docker rmi ", $1":"$2}' |sh -x
docker pull coredns/coredns:1.3.1
docker tag coredns/coredns:1.3.1 k8s.gcr.io/coredns:1.3.1
docker rmi coredns/coredns:1.3.1

```

3、查看镜像列表
```
docker images

REPOSITORY                           TAG                 IMAGE ID            CREATED             SIZE
k8s.gcr.io/kube-proxy                v1.15.3             232b5c793146        2 weeks ago         82.4MB
k8s.gcr.io/kube-scheduler            v1.15.3             703f9c69a5d5        2 weeks ago         81.1MB
k8s.gcr.io/kube-controller-manager   v1.15.3             e77c31de5547        2 weeks ago         159MB
k8s.gcr.io/coredns                   1.3.1               eb516548c180        7 months ago        40.3MB
k8s.gcr.io/etcd                      3.3.10              2c4adeb21b4f        9 months ago        258MB
k8s.gcr.io/pause                     3.1                 da86e6ba6ca1        20 months ago       742kB
```

参考文档：

https://cloud.tencent.com/info/6db42438f5dd7842bcecb6baf61833aa.html  kubeadm 无法下载镜像问题

https://juejin.im/post/5b8a4536e51d4538c545645c  使用kubeadm 部署 Kubernetes(国内环境)
