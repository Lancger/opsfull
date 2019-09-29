```
1、服务器IP更换网段  有什么解决方案吗？不重新搭建集群的话？

改监听地址，重做集群证书

不然还真不好搞的

如果etcd一开始是静态的 那就不好玩了

得一开始就是基于dns discovery方式

简明扼要的说

就是但凡涉及IP地址的地方

全部用fqdn

无论是证书还是配置文件

这四句话核心就够了

etcd官方本来就有正式文档讲dns discovery部署

只是k8s部分，官方部署没有提

这一点还真不算是kubeeasz的缺点 因为确实没有人做这件事
```

![](https://github.com/Lancger/opsfull/blob/master/images/change_ip_01.png)

![](https://github.com/Lancger/opsfull/blob/master/images/change_ip_02.png)

![](https://github.com/Lancger/opsfull/blob/master/images/change_ip_05.png)

![](https://github.com/Lancger/opsfull/blob/master/images/change_ip_06.png)


https://github.com/etcd-io/etcd/blob/a4018f25c91fff8f4f15cd2cee9f026650c7e688/Documentation/clustering.md#dns-discovery  
