Table of Contents
=================

   * [Kubernetes 中部署 NFS Provisioner 为 NFS 提供动态分配卷](#kubernetes-中部署-nfs-provisioner-为-nfs-提供动态分配卷)
      * [一、NFS Provisioner 简介](#一nfs-provisioner-简介)
      * [二、External NFS驱动的工作原理](#二external-nfs驱动的工作原理)
         * [1、nfs-client](#1nfs-client)
         * [2、nfs](#2nfs)
      * [三、部署服务](#三部署服务)
         * [1、配置授权](#1配置授权)
         * [2、部署nfs-client-provisioner](#2部署nfs-client-provisioner)
         * [3、部署NFS Provisioner](#3部署nfs-provisioner)
         * [4、创建StorageClass](#4创建storageclass)
   * [四、创建PVC](#四创建pvc)
   * [五、创建测试Pod](#五创建测试pod)
      * [01、进入 NFS Server 服务器验证是否创建对应文件](#01进入-nfs-server-服务器验证是否创建对应文件)
      
# Kubernetes 中部署 NFS Provisioner 为 NFS 提供动态分配卷

## 一、NFS Provisioner 简介

NFS Provisioner 是一个自动配置卷程序，它使用现有的和已配置的 NFS 服务器来支持通过持久卷声明动态配置 Kubernetes 持久卷。

- 持久卷被配置为：namespace−{pvcName}-${pvName}。

## 二、External NFS驱动的工作原理

K8S的外部NFS驱动，可以按照其工作方式（是作为NFS server还是NFS client）分为两类：

### 1、nfs-client

- 也就是我们接下来演示的这一类，它通过K8S的内置的NFS驱动挂载远端的NFS服务器到本地目录；然后将自身作为storage provider，关联storage class。当用户创建对应的PVC来申请PV时，该provider就将PVC的要求与自身的属性比较，一旦满足就在本地挂载好的NFS目录中创建PV所属的子目录，为Pod提供动态的存储服务。

### 2、nfs

- 与nfs-client不同，该驱动并不使用k8s的NFS驱动来挂载远端的NFS到本地再分配，而是直接将本地文件映射到容器内部，然后在容器内使用ganesha.nfsd来对外提供NFS服务；在每次创建PV的时候，直接在本地的NFS根目录中创建对应文件夹，并export出该子目录。利用NFS动态提供Kubernetes后端存储卷

- 本文将介绍使用nfs-client-provisioner这个应用，利用NFS Server给Kubernetes作为持久存储的后端，并且动态提供PV。前提条件是有已经安装好的NFS服务器，并且NFS服务器与Kubernetes的Slave节点都能网络连通。将nfs-client驱动做一个deployment部署到K8S集群中，然后对外提供存储服务。

`nfs-client-provisioner` 是一个Kubernetes的简易NFS的外部 provisioner，本身不提供NFS，需要现有的NFS服务器提供存储

## 三、部署服务

### 1、配置授权

现在的 Kubernetes 集群大部分是基于 RBAC 的权限控制，所以创建一个一定权限的 ServiceAccount 与后面要创建的 “NFS Provisioner” 绑定，赋予一定的权限。

```bash
# 清理rbac授权
kubectl delete -f nfs-rbac.yaml -n kube-system

# 编写yaml
cat >nfs-rbac.yaml<<-EOF
---
kind: ServiceAccount
apiVersion: v1
metadata:
  name: nfs-client-provisioner
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: nfs-client-provisioner-runner
rules:
  - apiGroups: [""]
    resources: ["persistentvolumes"]
    verbs: ["get", "list", "watch", "create", "delete"]
  - apiGroups: [""]
    resources: ["persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "update"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["create", "update", "patch"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: run-nfs-client-provisioner
subjects:
  - kind: ServiceAccount
    name: nfs-client-provisioner
    namespace: kube-system
roleRef:
  kind: ClusterRole
  name: nfs-client-provisioner-runner
  apiGroup: rbac.authorization.k8s.io
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: leader-locking-nfs-client-provisioner
rules:
  - apiGroups: [""]
    resources: ["endpoints"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: leader-locking-nfs-client-provisioner
subjects:
  - kind: ServiceAccount
    name: nfs-client-provisioner
    # replace with namespace where provisioner is deployed
    namespace: kube-system
roleRef:
  kind: Role
  name: leader-locking-nfs-client-provisioner
  apiGroup: rbac.authorization.k8s.io
EOF

# 应用授权
kubectl apply -f nfs-rbac.yaml -n kube-system
```

### 2、部署nfs-client-provisioner

首先克隆仓库获取yaml文件
```
git clone https://github.com/kubernetes-incubator/external-storage.git
cp -R external-storage/nfs-client/deploy/ /root/
cd deploy
```
### 3、部署NFS Provisioner

修改deployment.yaml文件,这里修改的参数包括NFS服务器所在的IP地址（10.198.1.155），以及NFS服务器共享的路径（/data/nfs/），两处都需要修改为你实际的NFS服务器和共享目录。另外修改nfs-client-provisioner镜像从七牛云拉取。

设置 NFS Provisioner 部署文件，这里将其部署到 “kube-system” Namespace 中。

```bash
# 清理NFS Provisioner资源
kubectl delete -f nfs-provisioner-deploy.yaml -n kube-system

export NFS_ADDRESS='10.198.1.155'
export NFS_DIR='/data/nfs'

# 编写deployment.yaml
cat >nfs-provisioner-deploy.yaml<<-EOF
---
kind: Deployment
apiVersion: apps/v1
metadata:
  name: nfs-client-provisioner
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nfs-client-provisioner
  strategy:
    type: Recreate  #---设置升级策略为删除再创建(默认为滚动更新)
  template:
    metadata:
      labels:
        app: nfs-client-provisioner
    spec:
      serviceAccountName: nfs-client-provisioner
      containers:
        - name: nfs-client-provisioner
          #---由于quay.io仓库国内被墙，所以替换成七牛云的仓库
          image: quay-mirror.qiniu.com/external_storage/nfs-client-provisioner:latest
          volumeMounts:
            - name: nfs-client-root
              mountPath: /persistentvolumes
          env:
            - name: PROVISIONER_NAME
              value: nfs-client  #---nfs-provisioner的名称，以后设置的storageclass要和这个保持一致
            - name: NFS_SERVER
              value: ${NFS_ADDRESS}  #---NFS服务器地址，和 valumes 保持一致
            - name: NFS_PATH
              value: ${NFS_DIR}  #---NFS服务器目录，和 valumes 保持一致
      volumes:
        - name: nfs-client-root
          nfs:
            server: ${NFS_ADDRESS}  #---NFS服务器地址
            path: ${NFS_DIR} #---NFS服务器目录
EOF

# 部署deployment.yaml
kubectl apply -f nfs-provisioner-deploy.yaml -n kube-system

# 查看创建的pod
kubectl get pod -o wide -n kube-system|grep nfs-client

# 查看pod日志
kubectl logs -f `kubectl get pod -o wide -n kube-system|grep nfs-client|awk '{print $1}'` -n kube-system
```

### 4、创建StorageClass

storage class的定义，需要注意的是：provisioner属性要等于驱动所传入的环境变量`PROVISIONER_NAME`的值。否则，驱动不知道知道如何绑定storage class。
此处可以不修改，或者修改provisioner的名字，需要与上面的deployment的`PROVISIONER_NAME`名字一致。

```bash
# 清理storageclass资源
kubectl delete -f nfs-storage.yaml

# 编写yaml
cat >nfs-storage.yaml<<-EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nfs-storage
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"  #---设置为默认的storageclass
provisioner: nfs-client  #---动态卷分配者名称，必须和上面创建的"PROVISIONER_NAME"变量中设置的Name一致
parameters:
  archiveOnDelete: "true"  #---设置为"false"时删除PVC不会保留数据,"true"则保留数据
mountOptions: 
  - hard        #指定为硬挂载方式
  - nfsvers=4   #指定NFS版本，这个需要根据 NFS Server 版本号设置
EOF

#部署class.yaml
kubectl apply -f nfs-storage.yaml

#查看创建的storageclass
$ kubectl get sc
NAME                    PROVISIONER      AGE
nfs-storage (default)   nfs-client       3m38s
```

## 四、创建PVC

### 01、创建一个新的namespace，然后创建pvc资源

```bash
# 删除命令空间
kubectl delete ns kube-public

# 创建命名空间
kubectl create ns kube-public

# 清理pvc
kubectl delete -f test-claim.yaml -n kube-public

# 编写yaml
cat >test-claim.yaml<<\EOF
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: test-claim
spec:
  storageClassName: nfs-storage #---需要与上面创建的storageclass的名称一致
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 100Gi
EOF

#创建PVC
kubectl apply -f test-claim.yaml -n kube-public

#查看创建的PV和PVC
$ kubectl get pvc -n kube-public
NAME         STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
test-claim   Bound    pvc-593f241f-a75f-459a-af18-a672e5090921   100Gi      RWX            nfs-storage    3s

kubectl get pv

#然后，我们进入到NFS的export目录，可以看到对应该volume name的目录已经创建出来了。其中volume的名字是namespace，PVC name以及uuid的组合：

#注意，出现pvc在pending的原因可能为nfs-client-provisioner pod 出现了问题，删除重建的时候会出现镜像问题
```

## 五、创建测试Pod

```bash
# 清理资源
kubectl delete -f test-pod.yaml -n kube-public

# 编写yaml
cat > test-pod.yaml <<\EOF
kind: Pod
apiVersion: v1
metadata:
  name: test-pod
spec:
  containers:
  - name: test-pod
    image: busybox:latest
    command:
      - "/bin/sh"
    args:
      - "-c"
      - "touch /mnt/SUCCESS && exit 0 || exit 1"
    volumeMounts:
      - name: nfs-pvc
        mountPath: "/mnt"
  restartPolicy: "Never"
  volumes:
    - name: nfs-pvc
      persistentVolumeClaim:
        claimName: test-claim
EOF

#创建pod
kubectl apply -f test-pod.yaml -n kube-public

#查看创建的pod
kubectl get pod -o wide -n kube-public
```

### 01、进入 NFS Server 服务器验证是否创建对应文件

进入 NFS Server 服务器的 NFS 挂载目录，查看是否存在 Pod 中创建的文件：

```bash
$ cd /data/nfs/
$ ls
archived-kube-public-test-claim-pvc-2dd4740d-f2d1-4e88-a0fc-383c00e37255  kube-public-test-claim-pvc-ad304939-e75d-414f-81b5-7586ef17db6c
archived-kube-public-test-claim-pvc-593f241f-a75f-459a-af18-a672e5090921  kube-system-test1-claim-pvc-f84dc09c-b41e-4e67-a239-b14f8d342efc
archived-kube-public-test-claim-pvc-b08b209d-c448-4ce4-ab5c-1bf37cc568e6  pv001
default-test-claim-pvc-4f18ed06-27cd-465b-ac87-b2e0e9565428               pv002

# 可以看到已经生成 SUCCESS 该文件，并且可知通过 NFS Provisioner 创建的目录命名方式为 “namespace名称-pvc名称-pv名称”，pv 名称是随机字符串，所以每次只要不删除 PVC，那么 Kubernetes 中的与存储绑定将不会丢失，要是删除 PVC 也就意味着删除了绑定的文件夹，下次就算重新创建相同名称的 PVC，生成的文件夹名称也不会一致，因为 PV 名是随机生成的字符串，而文件夹命名又跟 PV 有关,所以删除 PVC 需谨慎。
```


参考文档：

https://blog.csdn.net/qq_25611295/article/details/86065053  k8s pv与pvc持久化存储（静态与动态）

https://blog.csdn.net/networken/article/details/86697018 kubernetes部署NFS持久存储

https://www.jianshu.com/p/5e565a8049fc  kubernetes部署NFS持久存储（静态和动态）
