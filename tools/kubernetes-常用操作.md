# 一、节点调度配置
```
[root@master01 ~]# kubectl get nodes -A       
NAME          STATUS                     ROLES    AGE     VERSION
10.19.2.246   Ready                      node     3h13m   v1.15.2
10.19.2.247   Ready                      node     3h13m   v1.15.2
10.19.2.248   Ready                      node     3h13m   v1.15.2
10.19.2.56    Ready,SchedulingDisabled   master   4h55m   v1.15.2
10.19.2.57    Ready,SchedulingDisabled   master   4h55m   v1.15.2
10.19.2.58    Ready,SchedulingDisabled   master   4h55m   v1.15.2

#方法一
[root@master01 ~]# kubectl uncordon 10.19.2.56
node/10.19.2.56 uncordoned

[root@master01 ~]# kubectl get nodes -A       
NAME          STATUS                     ROLES    AGE     VERSION
10.19.2.246   Ready                      node     3h13m   v1.15.2
10.19.2.247   Ready                      node     3h13m   v1.15.2
10.19.2.248   Ready                      node     3h13m   v1.15.2
10.19.2.56    Ready                      master   4h56m   v1.15.2
10.19.2.57    Ready,SchedulingDisabled   master   4h56m   v1.15.2
10.19.2.58    Ready,SchedulingDisabled   master   4h56m   v1.15.2

#方法二
[root@master01 ~]# kubectl patch node 10.19.2.56 -p '{"spec":{"unschedulable":false}}'
node/10.19.2.56 patched

[root@master01 ~]# kubectl get nodes -A
NAME          STATUS                     ROLES    AGE     VERSION
10.19.2.246   Ready                      node     3h17m   v1.15.2
10.19.2.247   Ready                      node     3h17m   v1.15.2
10.19.2.248   Ready                      node     3h17m   v1.15.2
10.19.2.56    Ready                      master   5h      v1.15.2
10.19.2.57    Ready,SchedulingDisabled   master   5h      v1.15.2
10.19.2.58    Ready,SchedulingDisabled   master   5h      v1.15.2
```

# 二、标签查看
```
[root@master01 ~]# kubectl get nodes --show-labels
NAME          STATUS                     ROLES    AGE     VERSION   LABELS
10.19.2.246   Ready                      node     3h15m   v1.15.2   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=10.19.2.246,kubernetes.io/os=linux,kubernetes.io/role=node
10.19.2.247   Ready                      node     3h15m   v1.15.2   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=10.19.2.247,kubernetes.io/os=linux,kubernetes.io/role=node
10.19.2.248   Ready                      node     3h15m   v1.15.2   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=10.19.2.248,kubernetes.io/os=linux,kubernetes.io/role=node
10.19.2.56    Ready                      master   4h57m   v1.15.2   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=10.19.2.56,kubernetes.io/os=linux,kubernetes.io/role=master
10.19.2.57    Ready,SchedulingDisabled   master   4h57m   v1.15.2   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=10.19.2.57,kubernetes.io/os=linux,kubernetes.io/role=master
10.19.2.58    Ready,SchedulingDisabled   master   4h57m   v1.15.2   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=10.19.2.58,kubernetes.io/os=linux,kubernetes.io/role=master
```
参考文档：

https://blog.csdn.net/miss1181248983/article/details/88181434  Kubectl常用命令
