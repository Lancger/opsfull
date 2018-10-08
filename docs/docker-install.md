## 1.安装Docker

第一步：使用国内Docker源
```
cd /etc/yum.repos.d/
wget https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
 ```

第二步：Docker安装：
```
yum install -y docker-ce
```

第三步：启动后台进程：
```
#启动docker服务
systemctl start docker

#设置docker服务开启自启
systemctl enable docker
#Created symlink from /etc/systemd/system/multi-user.target.wants/docker.service to /usr/lib/systemd/system/docker.service.

#关闭docker服务开启自启
systemctl disable docker
#Removed symlink /etc/systemd/system/multi-user.target.wants/docker.service.
```
