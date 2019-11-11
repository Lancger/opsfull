# 一、PV（PersistentVolume）

PersistentVolume (PV) 是外部存储系统中的一块存储空间，由管理员创建和维护。与 Volume 一样，PV 具有持久性，生命周期独立于 Pod。

1、PV和PVC是一一对应关系，当有PV被某个PVC所占用时，会显示banding，其它PVC不能再使用绑定过的PV。

2、PVC一旦绑定PV，就相当于是一个存储卷，此时PVC可以被多个Pod所使用。（PVC支不支持被多个Pod访问，取决于访问模型accessMode的定义）。

3、PVC若没有找到合适的PV时，则会处于pending状态。

4、PV的reclaim policy选项：

    默认是Retain保留，保留生成的数据。
    可以改为recycle回收，删除生成的数据，回收pv
    delete，删除，pvc解除绑定后，pv也就自动删除。

# 二、PVC

PersistentVolumeClaim (PVC) 是对 PV 的申请 (Claim)。PVC 通常由普通用户创建和维护。需要为 Pod 分配存储资源时，用户可以创建一个 PVC，指明存储资源的容量大小和访问模式（比如只读）等信息，Kubernetes 会查找并提供满足条件的 PV。

## PVC资源需要指定：

1、accessMode：访问模型；对象列表：

    ReadWriteOnce – the volume can be mounted as read-write by a single node：  RWO - ReadWriteOnce  一人读写
    ReadOnlyMany – the volume can be mounted read-only by many nodes：          ROX - ReadOnlyMany   多人只读
    ReadWriteMany – the volume can be mounted as read-write by many nodes：     RWX - ReadWriteMany  多人读写
    
2、resource：资源限制（比如：定义5GB空间，我们期望对应的存储空间至少5GB。）  

3、selector：标签选择器。不加标签，就会在所有PV找最佳匹配。

4、storageClassName：存储类名称：

5、volumeMode：指后端存储卷的模式。可以用于做类型限制，哪种类型的PV可以被当前claim所使用。

6、volumeName：卷名称，指定后端PVC（相当于绑定）

   
# 三、两者差异

1、PV是属于集群级别的，不能定义在名称空间中

2、PVC时属于名称空间级别的。

参考文档：

https://blog.csdn.net/weixin_42973226/article/details/86501693  基于rook-ceph部署wordpress
