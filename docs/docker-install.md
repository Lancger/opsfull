## 1.安装Docker

第一步：使用国内Docker源
```
[root@linux-node1 ~]# cd /etc/yum.repos.d/
[root@linux-node1 yum.repos.d]# wget \
 https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
 ```

第二步：Docker安装：
```
[root@linux-node1 ~]# yum install -y docker-ce
```

第三步：启动后台进程：
```
[root@linux-node1 ~]# systemctl start docker
[root@linux-node1 ~]# systemctl enable docker
[root@linux-node1 ~]# systemctl disable docker
```
