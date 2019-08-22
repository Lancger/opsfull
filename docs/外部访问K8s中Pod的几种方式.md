```
Ingress是个什么鬼，网上资料很多（推荐官方），大家自行研究。简单来讲，就是一个负载均衡的玩意，其主要用来解决使用NodePort暴露Service的端口时Node IP会漂移的问题。同时，若大量使用NodePort暴露主机端口，管理会非常混乱。

好的解决方案就是让外界通过域名去访问Service，而无需关心其Node IP及Port。那为什么不直接使用Nginx？这是因为在K8S集群中，如果每加入一个服务，我们都在Nginx中添加一个配置，其实是一个重复性的体力活，只要是重复性的体力活，我们都应该通过技术将它干掉。

Ingress就可以解决上面的问题，其包含两个组件Ingress Controller和Ingress：

Ingress
将Nginx的配置抽象成一个Ingress对象，每添加一个新的服务只需写一个新的Ingress的yaml文件即可

Ingress Controller
将新加入的Ingress转化成Nginx的配置文件并使之生效
```

参考文档：

https://blog.csdn.net/qq_23348071/article/details/87185025  从外部访问K8s中Pod的五种方式
