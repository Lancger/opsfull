```
在没有pod 的yaml文件时，强制重启某个pod

kubectl get pod PODNAME -n NAMESPACE -o yaml | kubectl replace --force -f -
```
参考资料：

https://www.jianshu.com/p/baa6b11062de
