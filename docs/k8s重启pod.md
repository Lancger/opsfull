```
在没有pod 的yaml文件时，强制重启某个pod

kubectl get pod PODNAME -n NAMESPACE -o yaml | kubectl replace --force -f -

```

```
Q:如何进入一个 pod ？

kubectl  get  pod   查看pod name

kubectl describe pod    name_of_pod  查看pod详细信息

进入pod:

kubectl exec  -it   name-of-pod   bash

```
参考资料：

https://www.jianshu.com/p/baa6b11062de
