```
[root@master01 ~]# kubectl get nodes -A       
NAME          STATUS                     ROLES    AGE     VERSION
10.19.2.246   Ready                      node     3h13m   v1.15.2
10.19.2.247   Ready                      node     3h13m   v1.15.2
10.19.2.248   Ready                      node     3h13m   v1.15.2
10.19.2.56    Ready,SchedulingDisabled   master   4h55m   v1.15.2
10.19.2.57    Ready,SchedulingDisabled   master   4h55m   v1.15.2
10.19.2.58    Ready,SchedulingDisabled   master   4h55m   v1.15.2

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
```
参考文档：

https://blog.csdn.net/miss1181248983/article/details/88181434  Kubectl常用命令
