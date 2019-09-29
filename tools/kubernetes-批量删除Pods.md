```
kubectl get pods | grep Pending | awk '{print $1}' | xargs kubectl delete pod
```

参考文档：

https://blog.csdn.net/weixin_39686421/article/details/80574131  kubernetes-批量删除Evicted Pods
