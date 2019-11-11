# 一、MySQL持久化演练

数据库提供持久化存储，主要分为下面几个步骤：

    1、创建 PV 和 PVC

    2、部署 MySQL

    3、向 MySQL 添加数据

    4、模拟节点宕机故障，Kubernetes 将 MySQL 自动迁移到其他节点

    5、验证数据一致性


# 二、部署

1、创建 PV 和 PVC

```bash

```

参考文档：

https://blog.51cto.com/wzlinux/2330295   Kubernetes 之 MySQL 持久存储和故障转移(十一)

https://qingmu.io/2019/08/11/Run-mysql-on-kubernetes/ 从部署mysql聊一聊有状态服务和PV及PVC
