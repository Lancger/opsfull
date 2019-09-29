# 一、问题现象
```bash
heapster logs这个报错啥情况 
E0918 16:56:05.022867       1 manager.go:101] Error in scraping containers from kubelet_summary:10.10.188.242:10255: Get http://10.10.188.242:10255/stats/summary/: dial tcp 10.10.188.242:10255: getsockopt: connection refused
```
# 排查思路


```
1、排查下kubelet，10255是它暴露的端口

service kubelet status  #看状态是正常的

#在10.10.188.242上执行
[root@localhost ~]# netstat -lnpt | grep 10255
tcp        0      0 10.10.188.240:10255     0.0.0.0:*               LISTEN      9243/kubelet

看了下/var/log/pods/kube-system_heapster-5f848f54bc-rtbv4_abf53b7c-491f-472a-9e8b-815066a6ae3d/heapster下日志  所有的物理节点都是10255 拒绝连接


2、浏览器访问查看数据

10.10.188.242 是你节点的IP吧，正常的话浏览器访问http://IP:10255/stats/summary是有值的，你看下，如果没有那就是kubelet的配置出问题

```
![heapster获取数据异常](https://github.com/Lancger/opsfull/blob/master/images/heapster-01.png)
