# 一、前言

架构原理：每个Master都可以拥有多个Slave。当Master下线后，Redis集群会从多个Slave中选举出一个新的Master作为替代，而旧Master重新上线后变成新Master的Slave。

# 二、准备操作

本次部署主要基于该项目：

`https://github.com/zuxqoj/kubernetes-redis-cluster`

其包含了两种部署Redis集群的方式：
```
StatefulSet
Service&Deployment
```
两种方式各有优劣，对于像Redis、Mongodb、Zookeeper等有状态的服务，使用StatefulSet是首选方式。本文将主要介绍如何使用StatefulSet进行Redis集群的部署。

参考文档：

https://blog.csdn.net/zhutongcloud/article/details/90768390  在K8s上部署Redis集群
