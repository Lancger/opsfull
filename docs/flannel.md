1.为Flannel生成证书
```
[root@linux-node1 ~]# cd /usr/local/src/ssl/
[root@linux-node1 ssl]#
cat > flanneld-csr.json <<EOF
{
  "CN": "flanneld",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "k8s",
      "OU": "System"
    }
  ]
}
EOF
```

2.生成证书
```
[root@linux-node1 ssl]# cfssl gencert -ca=/opt/kubernetes/ssl/ca.pem \
   -ca-key=/opt/kubernetes/ssl/ca-key.pem \
   -config=/opt/kubernetes/ssl/ca-config.json \
   -profile=kubernetes flanneld-csr.json | cfssljson -bare flanneld
```

3.分发证书
```
[root@linux-node1 ssl]# cp flanneld*.pem /opt/kubernetes/ssl/
[root@linux-node1 ssl]# scp flanneld*.pem 192.168.56.12:/opt/kubernetes/ssl/
[root@linux-node1 ssl]# scp flanneld*.pem 192.168.56.13:/opt/kubernetes/ssl/
```

4.下载Flannel软件包
```
[root@linux-node1 ~]# cd /usr/local/src

# wget
 https://github.com/coreos/flannel/releases/download/v0.10.0/flannel-v0.10.0-linux-amd64.tar.gz
 
[root@linux-node1 src]# tar zxf flannel-v0.10.0-linux-amd64.tar.gz
[root@linux-node1 src]# cp flanneld mk-docker-opts.sh /opt/kubernetes/bin/

#复制到linux-node2节点
[root@linux-node1 src]# scp flanneld mk-docker-opts.sh 192.168.56.12:/opt/kubernetes/bin/
[root@linux-node1 src]# scp flanneld mk-docker-opts.sh 192.168.56.13:/opt/kubernetes/bin/

#复制对应脚本到/opt/kubernetes/bin目录下。
[root@linux-node1 ~]# cd /usr/local/src/kubernetes/cluster/centos/node/bin/
[root@linux-node1 bin]# cp remove-docker0.sh /opt/kubernetes/bin/
[root@linux-node1 bin]# scp remove-docker0.sh 192.168.56.12:/opt/kubernetes/bin/
[root@linux-node1 bin]# scp remove-docker0.sh 192.168.56.13:/opt/kubernetes/bin/
```

5.配置Flannel
```
[root@linux-node1 ~]# vim /opt/kubernetes/cfg/flannel
FLANNEL_ETCD="-etcd-endpoints=https://192.168.56.11:2379,https://192.168.56.12:2379,https://192.168.56.13:2379"
FLANNEL_ETCD_KEY="-etcd-prefix=/kubernetes/network"
FLANNEL_ETCD_CAFILE="--etcd-cafile=/opt/kubernetes/ssl/ca.pem"
FLANNEL_ETCD_CERTFILE="--etcd-certfile=/opt/kubernetes/ssl/flanneld.pem"
FLANNEL_ETCD_KEYFILE="--etcd-keyfile=/opt/kubernetes/ssl/flanneld-key.pem"

#复制配置到其它节点上
[root@linux-node1 ~]# scp /opt/kubernetes/cfg/flannel 192.168.56.12:/opt/kubernetes/cfg/
[root@linux-node1 ~]# scp /opt/kubernetes/cfg/flannel 192.168.56.13:/opt/kubernetes/cfg/
```

6.设置Flannel系统服务
```
[root@linux-node1 ~]# vim /usr/lib/systemd/system/flannel.service
[Unit]
Description=Flanneld overlay address etcd agent
After=network.target
Before=docker.service

[Service]
EnvironmentFile=-/opt/kubernetes/cfg/flannel
ExecStartPre=/opt/kubernetes/bin/remove-docker0.sh
ExecStart=/opt/kubernetes/bin/flanneld ${FLANNEL_ETCD} ${FLANNEL_ETCD_KEY} ${FLANNEL_ETCD_CAFILE} ${FLANNEL_ETCD_CERTFILE} ${FLANNEL_ETCD_KEYFILE}
ExecStartPost=/opt/kubernetes/bin/mk-docker-opts.sh -d /run/flannel/docker

Type=notify

[Install]
WantedBy=multi-user.target
RequiredBy=docker.service

#复制系统服务脚本到其它节点上
[root@linux-node1 ~]# scp /usr/lib/systemd/system/flannel.service 192.168.56.12:/usr/lib/systemd/system/
[root@linux-node1 ~]# scp /usr/lib/systemd/system/flannel.service 192.168.56.13:/usr/lib/systemd/system/
```

## Flannel CNI集成
下载CNI插件
```
https://github.com/containernetworking/plugins/releases

[root@linux-node1 ~]# cd /usr/local/src/
[root@linux-node1 src]# wget https://github.com/containernetworking/plugins/releases/download/v0.7.1/cni-plugins-amd64-v0.7.1.tgz
[root@linux-node1 src]# mkdir /opt/kubernetes/bin/cni
[root@linux-node1 src]# tar zxf cni-plugins-amd64-v0.7.1.tgz -C /opt/kubernetes/bin/cni
[root@linux-node1 src]# scp -r /opt/kubernetes/bin/cni/* 192.168.56.12:/opt/kubernetes/bin/cni/
[root@linux-node1 src]# scp -r /opt/kubernetes/bin/cni/* 192.168.56.13:/opt/kubernetes/bin/cni/
```

创建Etcd的key
```
/opt/kubernetes/bin/etcdctl --ca-file /opt/kubernetes/ssl/ca.pem --cert-file /opt/kubernetes/ssl/flanneld.pem --key-file /opt/kubernetes/ssl/flanneld-key.pem \
      --no-sync -C https://192.168.56.11:2379,https://192.168.56.12:2379,https://192.168.56.13:2379 \
mk /kubernetes/network/config '{ "Network": "10.2.0.0/16", "Backend": { "Type": "vxlan", "VNI": 1 }}' >/dev/null 2>&1
```

启动flannel
```
[root@linux-node1 ~]# systemctl daemon-reload
[root@linux-node1 ~]# systemctl enable flannel
[root@linux-node1 ~]# chmod +x /opt/kubernetes/bin/*
[root@linux-node1 ~]# systemctl start flannel
```

查看服务状态
```
[root@linux-node1 ~]# systemctl status flannel
```

## 配置Docker使用Flannel
```
[root@linux-node1 ~]# vim /usr/lib/systemd/system/docker.service
[Unit] #在Unit下面修改After和增加Requires
After=network-online.target flannel.service
Wants=network-online.target
Requires=flannel.service

[Service] #增加EnvironmentFile=-/run/flannel/docker
Type=notify
EnvironmentFile=-/run/flannel/docker
ExecStart=/usr/bin/dockerd $DOCKER_OPTS

#最终配置
cat /usr/lib/systemd/system/docker.service
[Unit]
Description=Docker Application Container Engine
Documentation=http://docs.docker.com
After=network.target flannel.service
Requires=flannel.service

[Service]
Type=notify
EnvironmentFile=-/run/flannel/docker
EnvironmentFile=-/opt/kubernetes/cfg/docker
ExecStart=/usr/bin/dockerd $DOCKER_OPT_BIP $DOCKER_OPT_MTU $DOCKER_OPTS
LimitNOFILE=1048576
LimitNPROC=1048576
ExecReload=/bin/kill -s HUP $MAINPID
# Having non-zero Limit*s causes performance problems due to accounting overhead
# in the kernel. We recommend using cgroups to do container-local accounting.
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
# Uncomment TasksMax if your systemd version supports it.
# Only systemd 226 and above support this version.
#TasksMax=infinity
TimeoutStartSec=0
# set delegate yes so that systemd does not reset the cgroups of docker containers
Delegate=yes
# kill only the docker process, not all processes in the cgroup
KillMode=process
# restart the docker process if it exits prematurely
Restart=on-failure
StartLimitBurst=3
StartLimitInterval=60s

[Install]
WantedBy=multi-user.target
```

将配置复制到另外两个阶段
```
[root@linux-node1 ~]# scp /usr/lib/systemd/system/docker.service 192.168.56.12:/usr/lib/systemd/system/
[root@linux-node1 ~]# scp /usr/lib/systemd/system/docker.service 192.168.56.13:/usr/lib/systemd/system/
```

重启Docker
```
systemctl daemon-reload
systemctl restart docker
```
