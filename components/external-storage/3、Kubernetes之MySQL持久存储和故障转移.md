我们演示如何为 MySQL 数据库提供持久化存储，主要分为下面几个步骤：

创建 PV 和 PVC。
部署 MySQL。
向 MySQL 添加数据。
模拟节点宕机故障，Kubernetes 将 MySQL 自动迁移到其他节点。
验证数据一致性。


参考文档：

https://blog.51cto.com/wzlinux/2330295   Kubernetes 之 MySQL 持久存储和故障转移(十一)
