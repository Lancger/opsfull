## 一、备份原yum源

```
curl http://mirrors.aliyun.com/repo/Centos-7.repo >/etc/yum.repos.d/Centos-7.repo
curl http://mirrors.aliyun.com/repo/epel-7.repo >/etc/yum.repos.d/epel-7.repo
sed -i '/aliyuncs/d' /etc/yum.repos.d/Centos-7.repo
yum makecache fast

yum -y install yum-utils
yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
yum install -y device-mapper-persistent-data lvm2

yum -y install docker
systemctl docker restart
```
# 一、创建docker用户和用户组
```
groupadd docker
useradd docker -G docker
echo "123456" | passwd --stdin docker

sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config # 关闭selinux
systemctl stop firewalld.service && systemctl disable firewalld.service # 关闭防火墙
#echo 'LANG="en_US.UTF-8"' >> /etc/profile; source /etc/profile # 修改系统语言
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime # 修改时区（如果需要修改）

# 性能调优
cat >> /etc/sysctl.conf<<EOF
net.ipv4.ip_forward=1
net.bridge.bridge-nf-call-iptables=1
net.ipv4.neigh.default.gc_thresh1=4096
net.ipv4.neigh.default.gc_thresh2=6144
net.ipv4.neigh.default.gc_thresh3=8192
EOF
sysctl –p

cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
vm.swappiness=0
EOF
sysctl --system
```
