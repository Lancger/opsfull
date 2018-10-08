
# 手动部署ETCD集群

## 0.准备etcd软件包
```
[root@linux-node1 src]# wget https://github.com/coreos/etcd/releases/download/v3.2.18/etcd-v3.2.18-linux-amd64.tar.gz
[root@linux-node1 src]# tar zxf etcd-v3.2.18-linux-amd64.tar.gz
[root@linux-node1 src]# cd etcd-v3.2.18-linux-amd64
[root@linux-node1 etcd-v3.2.18-linux-amd64]# cp etcd etcdctl /opt/kubernetes/bin/ 
[root@linux-node1 etcd-v3.2.18-linux-amd64]# scp etcd etcdctl 192.168.56.12:/opt/kubernetes/bin/
[root@linux-node1 etcd-v3.2.18-linux-amd64]# scp etcd etcdctl 192.168.56.13:/opt/kubernetes/bin/
```

## 1.创建 etcd 证书签名请求：
```
#约定所有证书都放在 /usr/local/src/ssl 目录中，然后同步到其他机器

[root@linux-node1 ~]# cd /usr/local/src/ssl
[root@linux-node1 ssl]# 
cat > etcd-csr.json <<EOF
{
  "CN": "etcd",
  "hosts": [
    "127.0.0.1",
    "192.168.56.11",
    "192.168.56.12",
    "192.168.56.13"
  ],
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
[root@linux-node1 ssl]#
```

## 2.生成 etcd 证书和私钥：
```
[root@linux-node1 ssl]# cfssl gencert -ca=/opt/kubernetes/ssl/ca.pem \
  -ca-key=/opt/kubernetes/ssl/ca-key.pem \
  -config=/opt/kubernetes/ssl/ca-config.json \
  -profile=kubernetes etcd-csr.json | cfssljson -bare etcd
  
2018/10/08 19:26:26 [INFO] generate received request
2018/10/08 19:26:26 [INFO] received CSR
2018/10/08 19:26:26 [INFO] generating key: rsa-2048
2018/10/08 19:26:26 [INFO] encoded CSR
2018/10/08 19:26:26 [INFO] signed certificate with serial number 674737706082810466537199547419623349216126693730
2018/10/08 19:26:26 [WARNING] This certificate lacks a "hosts" field. This makes it unsuitable for
websites. For more information see the Baseline Requirements for the Issuance and Management
of Publicly-Trusted Certificates, v.1.1.6, from the CA/Browser Forum (https://cabforum.org);
specifically, section 10.2.3 ("Information Requirements").
[root@linux-node1 ssl]#

#会生成以下证书文件
[root@linux-node1 ssl]# ls -l etcd*
-rw-r--r--. 1 root root 1062 Oct  8 19:26 etcd.csr
-rw-r--r--. 1 root root  299 Oct  8 19:24 etcd-csr.json
-rw-------. 1 root root 1675 Oct  8 19:26 etcd-key.pem
-rw-r--r--. 1 root root 1436 Oct  8 19:26 etcd.pem
```

## 3.将证书移动到/opt/kubernetes/ssl目录下
```
[root@linux-node1 ssl]# cp etcd*.pem /opt/kubernetes/ssl
[root@linux-node1 ssl]# scp etcd*.pem 192.168.56.12:/opt/kubernetes/ssl
[root@linux-node1 ssl]# scp etcd*.pem 192.168.56.13:/opt/kubernetes/ssl
[root@linux-node1 ssl]# rm -f etcd.csr etcd-csr.json
```

## 4.设置ETCD配置文件
```
#注意修改项（集群不同的地方）
##################################################
ETCD_NAME="etcd-node1"
ETCD_LISTEN_PEER_URLS="https://192.168.56.11:2380"   --2380集群监听的端口
ETCD_LISTEN_CLIENT_URLS="https://192.168.56.11:2379,https://127.0.0.1:2379"   --2379客户端监听的端口
##################################################

[root@linux-node1 ~]# vim /opt/kubernetes/cfg/etcd.conf
#[member]
ETCD_NAME="etcd-node1"
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"
#ETCD_SNAPSHOT_COUNTER="10000"
#ETCD_HEARTBEAT_INTERVAL="100"
#ETCD_ELECTION_TIMEOUT="1000"
ETCD_LISTEN_PEER_URLS="https://192.168.56.11:2380"
ETCD_LISTEN_CLIENT_URLS="https://192.168.56.11:2379,https://127.0.0.1:2379"
#ETCD_MAX_SNAPSHOTS="5"
#ETCD_MAX_WALS="5"
#ETCD_CORS=""
#[cluster]
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://192.168.56.11:2380"
# if you use different ETCD_NAME (e.g. test),
# set ETCD_INITIAL_CLUSTER value for this name, i.e. "test=http://..."
ETCD_INITIAL_CLUSTER="etcd-node1=https://192.168.56.11:2380,etcd-node2=https://192.168.56.12:2380,etcd-node3=https://192.168.56.13:2380"
ETCD_INITIAL_CLUSTER_STATE="new"
ETCD_INITIAL_CLUSTER_TOKEN="k8s-etcd-cluster"
ETCD_ADVERTISE_CLIENT_URLS="https://192.168.56.11:2379"
#[security]
CLIENT_CERT_AUTH="true"
ETCD_CA_FILE="/opt/kubernetes/ssl/ca.pem"
ETCD_CERT_FILE="/opt/kubernetes/ssl/etcd.pem"
ETCD_KEY_FILE="/opt/kubernetes/ssl/etcd-key.pem"
PEER_CLIENT_CERT_AUTH="true"
ETCD_PEER_CA_FILE="/opt/kubernetes/ssl/ca.pem"
ETCD_PEER_CERT_FILE="/opt/kubernetes/ssl/etcd.pem"
ETCD_PEER_KEY_FILE="/opt/kubernetes/ssl/etcd-key.pem"
```

## 5.创建ETCD系统服务
```
[root@linux-node1 ~]# vim /etc/systemd/system/etcd.service
[Unit]
Description=Etcd Server
After=network.target

[Service]
Type=simple
WorkingDirectory=/var/lib/etcd
EnvironmentFile=-/opt/kubernetes/cfg/etcd.conf
# set GOMAXPROCS to number of processors
ExecStart=/bin/bash -c "GOMAXPROCS=$(nproc) /opt/kubernetes/bin/etcd"
Type=notify

[Install]
WantedBy=multi-user.target
```

## 6.重新加载系统服务
```
[root@linux-node1 ~]# systemctl daemon-reload
[root@linux-node1 ~]# systemctl enable etcd

[root@linux-node1 ~]# scp /opt/kubernetes/cfg/etcd.conf 192.168.56.12:/opt/kubernetes/cfg/
[root@linux-node1 ~]# scp /etc/systemd/system/etcd.service 192.168.56.12:/etc/systemd/system/
[root@linux-node1 ~]# scp /opt/kubernetes/cfg/etcd.conf 192.168.56.13:/opt/kubernetes/cfg/
[root@linux-node1 ~]# scp /etc/systemd/system/etcd.service 192.168.56.13:/etc/systemd/system/

#在所有节点上创建etcd存储目录并启动etcd
mkdir /var/lib/etcd
systemctl start etcd
systemctl status etcd
```
## 7.修改集群其他节点差异配置文件
```
#node2配置文件
[root@linux-node2 src]# cat /opt/kubernetes/cfg/etcd.conf
#[member]
ETCD_NAME="etcd-node2"
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"
#ETCD_SNAPSHOT_COUNTER="10000"
#ETCD_HEARTBEAT_INTERVAL="100"
#ETCD_ELECTION_TIMEOUT="1000"
ETCD_LISTEN_PEER_URLS="https://192.168.56.12:2380"
ETCD_LISTEN_CLIENT_URLS="https://192.168.56.12:2379,https://127.0.0.1:2379"
#ETCD_MAX_SNAPSHOTS="5"
#ETCD_MAX_WALS="5"
#ETCD_CORS=""
#[cluster]
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://192.168.56.12:2380"
# if you use different ETCD_NAME (e.g. test),
# set ETCD_INITIAL_CLUSTER value for this name, i.e. "test=http://..."
ETCD_INITIAL_CLUSTER="etcd-node1=https://192.168.56.11:2380,etcd-node2=https://192.168.56.12:2380,etcd-node3=https://192.168.56.13:2380"
ETCD_INITIAL_CLUSTER_STATE="new"
ETCD_INITIAL_CLUSTER_TOKEN="k8s-etcd-cluster"
ETCD_ADVERTISE_CLIENT_URLS="https://192.168.56.12:2379"
#[security]
CLIENT_CERT_AUTH="true"
ETCD_CA_FILE="/opt/kubernetes/ssl/ca.pem"
ETCD_CERT_FILE="/opt/kubernetes/ssl/etcd.pem"
ETCD_KEY_FILE="/opt/kubernetes/ssl/etcd-key.pem"
PEER_CLIENT_CERT_AUTH="true"
ETCD_PEER_CA_FILE="/opt/kubernetes/ssl/ca.pem"
ETCD_PEER_CERT_FILE="/opt/kubernetes/ssl/etcd.pem"
ETCD_PEER_KEY_FILE="/opt/kubernetes/ssl/etcd-key.pem"

#node3配置文件
[root@linux-node3 src]# cat /opt/kubernetes/cfg/etcd.conf
#[member]
ETCD_NAME="etcd-node3"
ETCD_DATA_DIR="/var/lib/etcd/default.etcd"
#ETCD_SNAPSHOT_COUNTER="10000"
#ETCD_HEARTBEAT_INTERVAL="100"
#ETCD_ELECTION_TIMEOUT="1000"
ETCD_LISTEN_PEER_URLS="https://192.168.56.13:2380"
ETCD_LISTEN_CLIENT_URLS="https://192.168.56.13:2379,https://127.0.0.1:2379"
#ETCD_MAX_SNAPSHOTS="5"
#ETCD_MAX_WALS="5"
#ETCD_CORS=""
#[cluster]
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://192.168.56.13:2380"
# if you use different ETCD_NAME (e.g. test),
# set ETCD_INITIAL_CLUSTER value for this name, i.e. "test=http://..."
ETCD_INITIAL_CLUSTER="etcd-node1=https://192.168.56.11:2380,etcd-node2=https://192.168.56.12:2380,etcd-node3=https://192.168.56.13:2380"
ETCD_INITIAL_CLUSTER_STATE="new"
ETCD_INITIAL_CLUSTER_TOKEN="k8s-etcd-cluster"
ETCD_ADVERTISE_CLIENT_URLS="https://192.168.56.13:2379"
#[security]
CLIENT_CERT_AUTH="true"
ETCD_CA_FILE="/opt/kubernetes/ssl/ca.pem"
ETCD_CERT_FILE="/opt/kubernetes/ssl/etcd.pem"
ETCD_KEY_FILE="/opt/kubernetes/ssl/etcd-key.pem"
PEER_CLIENT_CERT_AUTH="true"
ETCD_PEER_CA_FILE="/opt/kubernetes/ssl/ca.pem"
ETCD_PEER_CERT_FILE="/opt/kubernetes/ssl/etcd.pem"
ETCD_PEER_KEY_FILE="/opt/kubernetes/ssl/etcd-key.pem"
```

下面需要大家在所有的 etcd 节点重复上面的步骤，直到所有机器的 etcd 服务都已启动。

## 8.验证集群
```
[root@linux-node1 ~]# etcdctl --endpoints=https://192.168.56.11:2379 \
  --ca-file=/opt/kubernetes/ssl/ca.pem \
  --cert-file=/opt/kubernetes/ssl/etcd.pem \
  --key-file=/opt/kubernetes/ssl/etcd-key.pem cluster-health
member 435fb0a8da627a4c is healthy: got healthy result from https://192.168.56.12:2379
member 6566e06d7343e1bb is healthy: got healthy result from https://192.168.56.11:2379
member ce7b884e428b6c8c is healthy: got healthy result from https://192.168.56.13:2379
cluster is healthy
```
