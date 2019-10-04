# study_docker

## 0.卸载旧版本
```bash
yum remove -y docker \
docker-client \
docker-client-latest \
docker-common \
docker-latest \
docker-latest-logrotate \
docker-logrotate \
docker-selinux \
docker-engine-selinux \
docker-engine
```

## 1.安装Docker

第一步：使用国内Docker源
```
cd /etc/yum.repos.d/
wget -O docker-ce.repo https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
 ```

第二步：Docker安装：
```
yum install -y docker-ce
```

第三步：启动后台进程：
```bash
#启动docker服务
systemctl restart docker

#设置docker服务开启自启
systemctl enable docker

#Created symlink from /etc/systemd/system/multi-user.target.wants/docker.service to /usr/lib/systemd/system/docker.service.

#查看是否成功设置docker服务开启自启
systemctl list-unit-files|grep docker

docker.service                                enabled

#关闭docker服务开启自启
systemctl disable docker

#Removed symlink /etc/systemd/system/multi-user.target.wants/docker.service.
```

## 2.脚本安装Docker
```bash
#2.1、Docker官方安装脚本
curl -sSL https://get.docker.com/ | sh

#这个脚本会添加docker.repo仓库并且安装Docker

#2.2、阿里云的安装脚本
curl -sSL http://acs-public-mirror.oss-cn-hangzhou.aliyuncs.com/docker-engine/internet | sh -

#2.3、DaoCloud 的安装脚本
curl -sSL https://get.daocloud.io/docker | sh

```

### 3.Docker服务文件
```bash
#注意，有变量的地方需要使用转义符号

cat > /usr/lib/systemd/system/docker.service << EOF
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
BindsTo=containerd.service
After=network-online.target firewalld.service containerd.service
Wants=network-online.target
Requires=docker.socket

[Service]
Type=notify
# the default is not to use systemd for cgroups because the delegate issues still
# exists and systemd currently does not support the cgroup feature set required
# for containers run by docker
ExecStart=/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock --exec-opt native.cgroupdriver=systemd
ExecReload=/bin/kill -s HUP \$MAINPID
ExecStartPost=/usr/sbin/iptables -P FORWARD ACCEPT
TimeoutSec=0
RestartSec=2
Restart=always

# Note that StartLimit* options were moved from "Service" to "Unit" in systemd 229.
# Both the old, and new location are accepted by systemd 229 and up, so using the old location
# to make them work for either version of systemd.
StartLimitBurst=3

# Note that StartLimitInterval was renamed to StartLimitIntervalSec in systemd 230.
# Both the old, and new name are accepted by systemd 230 and up, so using the old name to make
# this option work for either version of systemd.
StartLimitInterval=60s

# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity

# Comment TasksMax if your systemd version does not support it.
# Only systemd 226 and above support this option.
TasksMax=infinity

# set delegate yes so that systemd does not reset the cgroups of docker containers
Delegate=yes

# kill only the docker process, not all processes in the cgroup
KillMode=process

[Install]
WantedBy=multi-user.target
EOF
```
## 3.1、配置docker加速器
```bash
cat > /etc/docker/daemon.json << \EOF
{
  "registry-mirrors": [
    "https://dockerhub.azk8s.cn",
    "https://i37dz0y4.mirror.aliyuncs.com"
  ],
  "insecure-registries": ["reg.hub.com"]
}
EOF
```

### 3.2、重新加载docker的配置文件
```bash
systemctl daemon-reload
systemctl restart docker
```
### 3.3、内核参数配置
```bash
#编辑文件
vim /etc/sysctl.conf

net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1

#然后执行
sysctl -p

#查看docker信息是否生效
docker info
```

## 4.通过测试镜像运行一个容器来验证Docker是否安装正确
```bash
docker run hello-world
```
