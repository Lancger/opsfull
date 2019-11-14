PersistenVolume（PV）：对存储资源创建和使用的抽象，使得存储作为集群中的资源管理

PV分为静态和动态，动态能够自动创建PV

PersistentVolumeClaim（PVC）：让用户不需要关心具体的Volume实现细节

容器与PV、PVC之间的关系，可以如下图所示：

  ![PV](https://github.com/Lancger/opsfull/blob/master/images/pv01.png)

总的来说，PV是提供者，PVC是消费者，消费的过程就是绑定

# 问题一

pv挂载正常，pvc一直处于Pending状态

```bash 
#在test的命名空间创建pvc
$ kubectl get pvc -n test
NAME      STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
nfs-pvc   Pending---这里发现一直处于Pending的状态                                      nfs-storage    10s

#查看日志
$ kubectl describe pvc nfs-pvc -n test
failed to provision volume with StorageClass "nfs-storage": claim Selector is not supported
#从日志中发现，问题出在标签匹配的地方
```

参考资料：

https://blog.csdn.net/qq_25611295/article/details/86065053  k8s pv与pvc持久化存储（静态与动态）

https://www.jianshu.com/p/5e565a8049fc  kubernetes部署NFS持久存储（静态和动态）
