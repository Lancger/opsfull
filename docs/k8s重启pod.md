通过kubectl delete批量删除全部Pod
```
kubectl delete pod --all
```

```
在没有pod 的yaml文件时，强制重启某个pod

kubectl get pod PODNAME -n NAMESPACE -o yaml | kubectl replace --force -f -

```

```
Q:如何进入一个 pod ？

kubectl  get  pod   查看pod name

kubectl describe pod    name_of_pod  查看pod详细信息

进入pod:

[root@test001 ~]# kubectl get pod -o wide
NAME                                READY   STATUS    RESTARTS   AGE   IP            NODE         NOMINATED NODE   READINESS GATES
nginx-deployment-68c7f5464c-p52rl   1/1     Running   0          17m   172.20.1.22   10.33.35.6   <none>           <none>
nginx-deployment-68c7f5464c-qfd24   1/1     Running   0          17m   172.20.2.16   10.33.35.7   <none>           <none>

kubectl exec -it name-of-pod /bin/bash
```
参考资料：

https://www.jianshu.com/p/baa6b11062de
