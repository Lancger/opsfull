# 一、创建docker用户和用户组
```
groupadd docker
useradd docker -G docker
echo "123456" | passwd --stdin docker
```
