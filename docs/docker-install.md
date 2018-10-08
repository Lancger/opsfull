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
systemctl start docker

systemctl enable docker
#Created symlink from /etc/systemd/system/multi-user.target.wants/docker.service to /usr/lib/systemd/system/docker.service.

systemctl disable docker
#Removed symlink /etc/systemd/system/multi-user.target.wants/docker.service.
```
