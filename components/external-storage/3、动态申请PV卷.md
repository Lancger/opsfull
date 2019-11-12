# Kubernetes 中部署 NFS Provisioner 为 NFS 提供动态分配卷

## 一、NFS Provisioner 简介

NFS Provisioner 是一个自动配置卷程序，它使用现有的和已配置的 NFS 服务器来支持通过持久卷声明动态配置 Kubernetes 持久卷。

- 持久卷被配置为：𝑛𝑎𝑚𝑒𝑠𝑝𝑎𝑐𝑒−{pvcName}-${pvName}。

## 二、External NFS驱动的工作原理

K8S的外部NFS驱动，可以按照其工作方式（是作为NFS server还是NFS client）分为两类：

### 1、nfs-client:

也就是我们接下来演示的这一类，它通过K8S的内置的NFS驱动挂载远端的NFS服务器到本地目录；然后将自身作为storage provider，关联storage class。当用户创建对应的PVC来申请PV时，该provider就将PVC的要求与自身的属性比较，一旦满足就在本地挂载好的NFS目录中创建PV所属的子目录，为Pod提供动态的存储服务。

### 2、nfs:

与nfs-client不同，该驱动并不使用k8s的NFS驱动来挂载远端的NFS到本地再分配，而是直接将本地文件映射到容器内部，然后在容器内使用ganesha.nfsd来对外提供NFS服务；在每次创建PV的时候，直接在本地的NFS根目录中创建对应文件夹，并export出该子目录。利用NFS动态提供Kubernetes后端存储卷

本文将介绍使用nfs-client-provisioner这个应用，利用NFS Server给Kubernetes作为持久存储的后端，并且动态提供PV。前提条件是有已经安装好的NFS服务器，并且NFS服务器与Kubernetes的Slave节点都能网络连通。将nfs-client驱动做一个deployment部署到K8S集群中，然后对外提供存储服务。

nfs-client-provisioner 是一个Kubernetes的简易NFS的外部provisioner，本身不提供NFS，需要现有的NFS服务器提供存储

## 三、部署nfs-client-provisioner

首先克隆仓库获取yaml文件

```
git clone https://github.com/kubernetes-incubator/external-storage.git
cp -R external-storage/nfs-client/deploy/ /root/
cd deploy
```
2、修改deployment.yaml文件

这里修改的参数包括NFS服务器所在的IP地址（192.168.92.56），以及NFS服务器共享的路径（/nfs/data），两处都需要修改为你实际的NFS服务器和共享目录。另外修改nfs-client-provisioner镜像从dockerhub拉取。

```
kubectl delete -f deployment.yaml

export NFS_ADDRESS='10.198.1.156'
export NFS_DIR='/nfs/data'

cat >deployment.yaml<<-EOF
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
          #image: willdockerhub/nfs-client-provisioner:latest
          image: registry.cn-hangzhou.aliyuncs.com/open-ali/nfs-client-provisioner:latest
          volumeMounts:
            - name: nfs-client-root
              mountPath: /persistentvolumes
          env:
            - name: PROVISIONER_NAME
              value: fuseim.pri/ifs
            - name: NFS_SERVER
              value: ${NFS_ADDRESS}
            - name: NFS_PATH
              value: ${NFS_DIR}
      volumes:
        - name: nfs-client-root
          nfs:
            server: ${NFS_ADDRESS}
            path: ${NFS_DIR}
EOF

#部署deployment.yaml
kubectl apply -f deployment.yaml

#查看创建的pod
kubectl get pod -o wide
```

3、创建StorageClass

storage class的定义，需要注意的是：provisioner属性要等于驱动所传入的环境变量PROVISIONER_NAME的值。否则，驱动不知道知道如何绑定storage class。
此处可以不修改，或者修改provisioner的名字，需要与上面的deployment的PROVISIONER_NAME名字一致。

```
kubectl delete -f class.yaml

cat > class.yaml <<-EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: managed-nfs-storage
provisioner: fuseim.pri/ifs # or choose another name, must match deployment's env PROVISIONER_NAME'
parameters:
  archiveOnDelete: "false"
EOF

#部署class.yaml
kubectl apply -f class.yaml

#查看创建的storageclass
kubectl get sc
```

4、配置授权

如果集群启用了RBAC，则必须执行如下命令授权provisioner。

```
kubectl delete -f rbac.yaml

cat > rbac.yaml <<-EOF
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
    namespace: default
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
    namespace: default
roleRef:
  kind: Role
  name: leader-locking-nfs-client-provisioner
  apiGroup: rbac.authorization.k8s.io
EOF

#创建 RBAC
kubectl apply -f rbac.yaml

```

# 二、创建测试PVC
```
kubectl delete -f test-claim.yaml

cat >test-claim.yaml<<\EOF
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: test-claim
  annotations:
    volume.beta.kubernetes.io/storage-class: "managed-nfs-storage"
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 100Mi
EOF

#创建PVC
kubectl apply -f test-claim.yaml

#查看创建的PV和PVC
kubectl get pvc
kubectl get pv

然后，我们进入到NFS的export目录，可以看到对应该volume name的目录已经创建出来了。
其中volume的名字是namespace，PVC name以及uuid的组合：

注意，出现pvc在pending的原因可能为nfs-client-provisioner pod 出现了问题，删除重建的时候会出现镜像问题
```

# 三、创建测试Pod

```
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
kubectl apply -f test-pod.yaml

#查看创建的pod
kubectl get pod -o wide
```


参考文档：

https://blog.csdn.net/qq_25611295/article/details/86065053  k8s pv与pvc持久化存储（静态与动态）

https://blog.csdn.net/networken/article/details/86697018 kubernetes部署NFS持久存储

https://www.jianshu.com/p/5e565a8049fc  kubernetes部署NFS持久存储（静态和动态）
