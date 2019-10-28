# 动态申请PV卷

External NFS驱动的工作原理
K8S的外部NFS驱动，可以按照其工作方式（是作为NFS server还是NFS client）分为两类：

1.nfs-client:
也就是我们接下来演示的这一类，它通过K8S的内置的NFS驱动挂载远端的NFS服务器到本地目录；然后将自身作为storage provider，关联storage class。当用户创建对应的PVC来申请PV时，该provider就将PVC的要求与自身的属性比较，一旦满足就在本地挂载好的NFS目录中创建PV所属的子目录，为Pod提供动态的存储服务。

2.nfs:
与nfs-client不同，该驱动并不使用k8s的NFS驱动来挂载远端的NFS到本地再分配，而是直接将本地文件映射到容器内部，然后在容器内使用ganesha.nfsd来对外提供NFS服务；在每次创建PV的时候，直接在本地的NFS根目录中创建对应文件夹，并export出该子目录。
利用NFS动态提供Kubernetes后端存储卷

本文将介绍使用nfs-client-provisioner这个应用，利用NFS Server给Kubernetes作为持久存储的后端，并且动态提供PV。前提条件是有已经安装好的NFS服务器，并且NFS服务器与Kubernetes的Slave节点都能网络连通。将nfs-client驱动做一个deployment部署到K8S集群中，然后对外提供存储服务。
nfs-client-provisioner 是一个Kubernetes的简易NFS的外部provisioner，本身不提供NFS，需要现有的NFS服务器提供存储

1、部署nfs-client-provisioner
首先克隆仓库获取yaml文件
```
git clone https://github.com/kubernetes-incubator/external-storage.git
cp -R external-storage/nfs-client/deploy/ /root/
cd deploy
```
2、修改deployment.yaml文件

这里修改的参数包括NFS服务器所在的IP地址（192.168.92.56），以及NFS服务器共享的路径（/nfs/data），两处都需要修改为你实际的NFS服务器和共享目录。另外修改nfs-client-provisioner镜像从dockerhub拉取。

```
cat > deployment.yaml <<\EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: nfs-client-provisioner
---
kind: Deployment
apiVersion: extensions/v1beta1
metadata:
  name: nfs-client-provisioner
spec:
  replicas: 1
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: nfs-client-provisioner
    spec:
      serviceAccountName: nfs-client-provisioner
      containers:
        - name: nfs-client-provisioner
          #image: quay.io/external_storage/nfs-client-provisioner:latest
          image: quay-mirror.qiniu.com/external_storage/nfs-client-provisioner:latest
          volumeMounts:
            - name: nfs-client-root
              mountPath: /persistentvolumes
          env:
            - name: PROVISIONER_NAME
              value: nfs-client
            - name: NFS_SERVER
              value: 10.19.1.156
            - name: NFS_PATH
              value: /nfs/data
      volumes:
        - name: nfs-client-root
          nfs:
            server: 10.19.1.156
            path: /nfs/data
EOF
```

参考文档：

https://blog.csdn.net/networken/article/details/86697018 kubernetes部署NFS持久存储
