## 一.部署Kubernetes API服务部署
### 0.准备软件包
```
[root@linux-node1 ~]# cd /usr/local/src/kubernetes
[root@linux-node1 kubernetes]# cp server/bin/kube-apiserver /opt/kubernetes/bin/
[root@linux-node1 kubernetes]# cp server/bin/kube-controller-manager /opt/kubernetes/bin/
[root@linux-node1 kubernetes]# cp server/bin/kube-scheduler /opt/kubernetes/bin/
```

### 1.创建生成CSR的 JSON 配置文件
```
[root@linux-node1 ~]# cd /usr/local/src/ssl
[root@linux-node1 ssl]#
cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "hosts": [
    "127.0.0.1",
    "192.168.56.11",
    "10.1.0.1",
    "kubernetes",
    "kubernetes.default",
    "kubernetes.default.svc",
    "kubernetes.default.svc.cluster",
    "kubernetes.default.svc.cluster.local"
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
```

### 2.生成 kubernetes 证书和私钥
```
[root@linux-node1 ssl]# cfssl gencert -ca=/opt/kubernetes/ssl/ca.pem \
   -ca-key=/opt/kubernetes/ssl/ca-key.pem \
   -config=/opt/kubernetes/ssl/ca-config.json \
   -profile=kubernetes kubernetes-csr.json | cfssljson -bare kubernetes
[root@linux-node1 ssl]# cp kubernetes*.pem /opt/kubernetes/ssl/
[root@linux-node1 ssl]# scp kubernetes*.pem 192.168.56.12:/opt/kubernetes/ssl/
[root@linux-node1 ssl]# scp kubernetes*.pem 192.168.56.13:/opt/kubernetes/ssl/
```

### 3.创建 kube-apiserver 使用的客户端 token 文件
```
[root@linux-node1 ssl]# head -c 16 /dev/urandom | od -An -t x | tr -d ' '
ad6d5bb607a186796d8861557df0d17f 
[root@linux-node1 ~]# vim /opt/kubernetes/ssl/bootstrap-token.csv
ad6d5bb607a186796d8861557df0d17f,kubelet-bootstrap,10001,"system:kubelet-bootstrap"
```

### 4.创建基础用户名/密码认证配置
```
[root@linux-node1 ~]# vim /opt/kubernetes/ssl/basic-auth.csv
admin,admin,1
readonly,readonly,2
```

### 5.部署Kubernetes API Server
```
#正常日志在 /opt/kubernetes/log 目录中查看，启动异常日志在 /var/log/messages 中查看

[root@linux-node1 ~]# vim /usr/lib/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=network.target

[Service]
ExecStart=/opt/kubernetes/bin/kube-apiserver \
  --admission-control=NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota,NodeRestriction \
  --bind-address=192.168.56.11 \
  --insecure-bind-address=127.0.0.1 \
  --authorization-mode=Node,RBAC \
  --runtime-config=rbac.authorization.k8s.io/v1 \
  --kubelet-https=true \
  --anonymous-auth=false \
  --basic-auth-file=/opt/kubernetes/ssl/basic-auth.csv \
  --enable-bootstrap-token-auth \
  --token-auth-file=/opt/kubernetes/ssl/bootstrap-token.csv \
  --service-cluster-ip-range=10.1.0.0/16 \
  --service-node-port-range=20000-40000 \
  --tls-cert-file=/opt/kubernetes/ssl/kubernetes.pem \
  --tls-private-key-file=/opt/kubernetes/ssl/kubernetes-key.pem \
  --client-ca-file=/opt/kubernetes/ssl/ca.pem \
  --service-account-key-file=/opt/kubernetes/ssl/ca-key.pem \
  --etcd-cafile=/opt/kubernetes/ssl/ca.pem \
  --etcd-certfile=/opt/kubernetes/ssl/kubernetes.pem \
  --etcd-keyfile=/opt/kubernetes/ssl/kubernetes-key.pem \
  --etcd-servers=https://192.168.56.11:2379,https://192.168.56.12:2379,https://192.168.56.13:2379 \
  --enable-swagger-ui=true \
  --allow-privileged=true \
  --audit-log-maxage=30 \
  --audit-log-maxbackup=3 \
  --audit-log-maxsize=100 \
  --audit-log-path=/opt/kubernetes/log/api-audit.log \
  --event-ttl=1h \
  --v=2 \
  --logtostderr=false \
  --log-dir=/opt/kubernetes/log
Restart=on-failure
RestartSec=5
Type=notify
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```

### 6.启动API Server服务
```
[root@linux-node1 ~]# systemctl daemon-reload
[root@linux-node1 ~]# systemctl enable kube-apiserver
[root@linux-node1 ~]# systemctl start kube-apiserver
```

查看API Server服务状态
```
[root@linux-node1 ~]# systemctl status kube-apiserver

[root@linux-node1 ~]# netstat -ntlp
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name
tcp        0      0 192.168.56.11:6443      0.0.0.0:*               LISTEN      1508/kube-apiserver
tcp        0      0 192.168.56.11:2379      0.0.0.0:*               LISTEN      987/etcd
tcp        0      0 127.0.0.1:2379          0.0.0.0:*               LISTEN      987/etcd
tcp        0      0 192.168.56.11:2380      0.0.0.0:*               LISTEN      987/etcd
tcp        0      0 127.0.0.1:8080          0.0.0.0:*               LISTEN      1508/kube-apiserver
tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN      985/sshd
tcp6       0      0 :::22                   :::*                    LISTEN      985/sshd

#发现 kube-apiserver 会监听2个端口一个6443（需要认证），一个本地的8080(给kube-controller-manager和kube-scheduler服务使用，不需要认证，其他的服务访问apiserver就需要认证)
```

## 二.部署Controller Manager服务
```
[root@linux-node1 ~]# vim /usr/lib/systemd/system/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/opt/kubernetes/bin/kube-controller-manager \
  --address=127.0.0.1 \
  --master=http://127.0.0.1:8080 \
  --allocate-node-cidrs=true \
  --service-cluster-ip-range=10.1.0.0/16 \
  --cluster-cidr=10.2.0.0/16 \
  --cluster-name=kubernetes \
  --cluster-signing-cert-file=/opt/kubernetes/ssl/ca.pem \
  --cluster-signing-key-file=/opt/kubernetes/ssl/ca-key.pem \
  --service-account-private-key-file=/opt/kubernetes/ssl/ca-key.pem \
  --root-ca-file=/opt/kubernetes/ssl/ca.pem \
  --leader-elect=true \
  --v=2 \
  --logtostderr=false \
  --log-dir=/opt/kubernetes/log

Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

### 3.启动Controller Manager
```
[root@linux-node1 ~]# systemctl daemon-reload
[root@linux-node1 scripts]# systemctl enable kube-controller-manager
[root@linux-node1 scripts]# systemctl start kube-controller-manager
```

### 4.查看服务状态
```
[root@linux-node1 scripts]# systemctl status kube-controller-manager
```


## 三.部署Kubernetes Scheduler
```
[root@linux-node1 ~]# vim /usr/lib/systemd/system/kube-scheduler.service
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
ExecStart=/opt/kubernetes/bin/kube-scheduler \
  --address=127.0.0.1 \
  --master=http://127.0.0.1:8080 \
  --leader-elect=true \
  --v=2 \
  --logtostderr=false \
  --log-dir=/opt/kubernetes/log

Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

### 2.部署服务
```
[root@linux-node1 ~]# systemctl daemon-reload
[root@linux-node1 scripts]# systemctl enable kube-scheduler
[root@linux-node1 scripts]# systemctl start kube-scheduler
[root@linux-node1 scripts]# systemctl status kube-scheduler
```

## 四.部署kubectl命令行工具(管理k8s集群的工具，跟apiserver交互，通信需要认证)
（为了安全，只在master服务器上安装）

1.准备二进制命令包
```
[root@linux-node1 ~]# cd /usr/local/src/kubernetes/client/bin
[root@linux-node1 bin]# cp kubectl /opt/kubernetes/bin/
```

2.创建 admin 证书签名请求
```
[root@linux-node1 ~]# cd /usr/local/src/ssl/
[root@linux-node1 ssl]# 
cat > admin-csr.json <<EOF
{
  "CN": "admin",
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
      "O": "system:masters",
      "OU": "System"
    }
  ]
}
EOF
[root@linux-node1 ssl]#
```

3.生成 admin 证书和私钥：
```
[root@linux-node1 ssl]# cfssl gencert -ca=/opt/kubernetes/ssl/ca.pem \
   -ca-key=/opt/kubernetes/ssl/ca-key.pem \
   -config=/opt/kubernetes/ssl/ca-config.json \
   -profile=kubernetes admin-csr.json | cfssljson -bare admin
[root@linux-node1 ssl]# ls -l admin*
-rw-r--r-- 1 root root 1009 Mar  5 12:29 admin.csr
-rw-r--r-- 1 root root  229 Mar  5 12:28 admin-csr.json
-rw------- 1 root root 1675 Mar  5 12:29 admin-key.pem
-rw-r--r-- 1 root root 1399 Mar  5 12:29 admin.pem

[root@linux-node1 src]# cp admin*.pem /opt/kubernetes/ssl/
```

4.设置集群参数

apiserver通过RBAC给客户端授权，RBAC预定义了一些角色，我们需要对其进行配置

```
[root@linux-node1 src]# kubectl config set-cluster kubernetes \
   --certificate-authority=/opt/kubernetes/ssl/ca.pem \
   --embed-certs=true \
   --server=https://192.168.56.11:6443
Cluster "kubernetes" set.
```

5.设置客户端认证参数
```
[root@linux-node1 src]# kubectl config set-credentials admin \
   --client-certificate=/opt/kubernetes/ssl/admin.pem \
   --embed-certs=true \
   --client-key=/opt/kubernetes/ssl/admin-key.pem
User "admin" set.
```

6.设置上下文参数
```
[root@linux-node1 src]# kubectl config set-context kubernetes \
   --cluster=kubernetes \
   --user=admin
Context "kubernetes" created.
```

7.设置默认上下文
```
[root@linux-node1 src]# kubectl config use-context kubernetes
Switched to context "kubernetes".

#以上这么多操作，就是在当前家目录下生成了一个这个文件(如果其他节点也需要正常使用kubectl命令，需要将这个文件也同步到对应的目录)
[root@linux-node1 ~]# cat ~/.kube/config
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUR2akNDQXFhZ0F3SUJBZ0lVYmY4ODdHRDJMWDRubnJXOWwzR05hanVwcnBnd0RRWUpLb1pJaHZjTkFRRUwKQlFBd1pURUxNQWtHQTFVRUJoTUNRMDR4RURBT0JnTlZCQWdUQjBKbGFXcHBibWN4RURBT0JnTlZCQWNUQjBKbAphV3BwYm1jeEREQUtCZ05WQkFvVEEyczRjekVQTUEwR0ExVUVDeE1HVTNsemRHVnRNUk13RVFZRFZRUURFd3ByCmRXSmxjbTVsZEdWek1CNFhEVEU0TVRBd09EQTRNalV3TUZvWERUSXpNVEF3TnpBNE1qVXdNRm93WlRFTE1Ba0cKQTFVRUJoTUNRMDR4RURBT0JnTlZCQWdUQjBKbGFXcHBibWN4RURBT0JnTlZCQWNUQjBKbGFXcHBibWN4RERBSwpCZ05WQkFvVEEyczRjekVQTUEwR0ExVUVDeE1HVTNsemRHVnRNUk13RVFZRFZRUURFd3ByZFdKbGNtNWxkR1Z6Ck1JSUJJakFOQmdrcWhraUc5dzBCQVFFRkFBT0NBUThBTUlJQkNnS0NBUUVBdXdURWFLM2xXeVJ4UDBJNjlPSnYKdy9hM3lkK0dRMW5FaWFuNVZBaFc3b25NQlF6OGJiUjRYU0E0SXJrMWJ5bTJacVNnQjduVDI2TlZvby94eDVSTAppUXJLN294SzlvZ01YUHJ4Y3NPYmxocG03eHFzMnEyUWhrOWN6YW5XTm1icnlYZ1BmbXg0NDNlZVZPaGZ6aWZ6ClRXbHozSDNpdDRvUW5YRytNSkpKZ2FhU211YUJBOVlHMUNZUGJ5Ym1JZENMZlc4ZFZOUjhyZkJkQnVGV1poRzEKMVVIS1UwNGs2ZS9uNDNJYTZ3bElNVTl2Y1Z0R1g2d0N5K3ozY291c1pqUGczakdzUEU5UC9HT2FyN2FPaVM3VQpNQXJMMkZWcnBnT3BJWmhyMFdBOW1iQjRyVS9Cb0VSUW5OWXhEQktHSWpCT1pIMTlrbmhKNlllVm5JRGphZHZGCkhRSURBUUFCbzJZd1pEQU9CZ05WSFE4QkFmOEVCQU1DQVFZd0VnWURWUjBUQVFIL0JBZ3dCZ0VCL3dJQkFqQWQKQmdOVkhRNEVGZ1FVVU1wY1kzS1pCYzB0a1UyNmw4OVpUSHhMRlNFd0h3WURWUjBqQkJnd0ZvQVVVTXBjWTNLWgpCYzB0a1UyNmw4OVpUSHhMRlNFd0RRWUpLb1pJaHZjTkFRRUxCUUFEZ2dFQkFDUWNoS05uMFNxMFIxNkJ1dFlQCmNBU2lqQnZxNHM1enZmdy9Ua29HaVVrVCtsYWI5ME0wNHJMbzRYK1prZk1WT3hIb0RBc3R5Uy9JN3ZXdU16K3EKeU82UzgwVlhBd200dDhkOEhXYlZtbStnSzFJcEE5Smg3TUJTa2VBZGsxM0FTcy90S1NpT3EwMFIwRklEWGxPWgpCd3lza0orN0FJU2prZlAvZGVXTGlhL2QzaUdISnA4UkZnb09EbWxpMWxtWklsMUQySVFJU1VCTE9GbTg0VGtxCmFtZzRscWNJdzlSM0VhT3l3YkJDeGtJaTk3T1JXT3NncVpmekR2MFUwLzhTZ0dPdis5bGJMdE95QjRwY09iRTkKZGdmWXVHMXZ2clpib01yeDFxdlhNckRDTitWZGxiZ0QrYkJ1NUxOTmpIWlZkRzdwYlc5bXZuUnV2UDVIMEFXLwpBT3M9Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K
    server: https://192.168.56.11:6443
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: admin
  name: kubernetes
current-context: kubernetes
kind: Config
preferences: {}
users:
- name: admin
  user:
    client-certificate-data: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUQzVENDQXNXZ0F3SUJBZ0lVR29PYThEaE9WQTNKajNzRkR2eUErVk9WdGhVd0RRWUpLb1pJaHZjTkFRRUwKQlFBd1pURUxNQWtHQTFVRUJoTUNRMDR4RURBT0JnTlZCQWdUQjBKbGFXcHBibWN4RURBT0JnTlZCQWNUQjBKbAphV3BwYm1jeEREQUtCZ05WQkFvVEEyczRjekVQTUEwR0ExVUVDeE1HVTNsemRHVnRNUk13RVFZRFZRUURFd3ByCmRXSmxjbTVsZEdWek1CNFhEVEU0TVRBd09ERXlNekF3TUZvWERUSTRNVEF3TlRFeU16QXdNRm93YXpFTE1Ba0cKQTFVRUJoTUNRMDR4RURBT0JnTlZCQWdUQjBKbGFVcHBibWN4RURBT0JnTlZCQWNUQjBKbGFVcHBibWN4RnpBVgpCZ05WQkFvVERuTjVjM1JsYlRwdFlYTjBaWEp6TVE4d0RRWURWUVFMRXdaVGVYTjBaVzB4RGpBTUJnTlZCQU1UCkJXRmtiV2x1TUlJQklqQU5CZ2txaGtpRzl3MEJBUUVGQUFPQ0FROEFNSUlCQ2dLQ0FRRUF0NExsNmRYQjVEMFQKZkNmN2xTR05rc2paRmNsYmFvZUlnTkhLbSs1NVI1aXZIQUN6dXBIM3J5bkEwMVE5VnE1NGRHQnRmZ0dQLzQveAp4Sy9kNnduMFVnaFZUWnRnQWVtRGVPTXhVSTVsT3ZmbURvNkwraFBCMjV6WldmSEltR1NJcXR6NWExMno5VURUCjNZdUlqNlpobWFzOGhIK2tKNCszL1FMZzlKTy9KYWFQTkgvT0pYZjNiS0N3YmxpMDBBdllQV0Mxa3NtbWxLZlIKNWdKV1lySUl2NEh2Y3plWFVqWkE4K0Nnc0hSdktOWlkybjh6RHRjZkFmSEhEY0FZTjZhVlZBODZJUytic3NlLwpLVS82T1BHbXZRNktWM05qZ1FUTml6eldUU0FhTFJyRVZiVkdraC9CRDg2QlNpbzI3aHBHeGtQekErbEJQK2xrClNLQXAzYUpyRHdJREFRQUJvMzh3ZlRBT0JnTlZIUThCQWY4RUJBTUNCYUF3SFFZRFZSMGxCQll3RkFZSUt3WUIKQlFVSEF3RUdDQ3NHQVFVRkJ3TUNNQXdHQTFVZEV3RUIvd1FDTUFBd0hRWURWUjBPQkJZRUZHR0Q1ZDhyTXlhSgpEdHhUa0pQaHNTaFk1MEZQTUI4R0ExVWRJd1FZTUJhQUZGREtYR055bVFYTkxaRk51cGZQV1V4OFN4VWhNQTBHCkNTcUdTSWIzRFFFQkN3VUFBNElCQVFCc2lHL25oRjZpUEMvTGZFR1RQaEdWejBwbVNYOEU2MVR4eVdXM2drYVYKZjB4Ry94RXBzRFRXUVhpQTBhbDRVbEJlQ1RJbFA0ZldLY0tOZS9BTXZlYkF2SnB0Q1ZjWTUrUkV0d214dnBCYwptcWRwdDhGTGdJdkNuYmN3RFppWVFNTGRkWWFRWHI3STRIeUxITDhBTm5CbmI5S3BZT0VMdFNYb2ltR1MydzFpCkJqVGgrK2lDb2htVXJFT3J4K1NjeWFadWV2L0RtczN1TFZnN1lscXVWUlJVMzNkdWJQaEx2bVJHRjB5ZjRHQXgKeUlaRCtYM0J5M2VBTzhyWW9oQVk3VXhXTDVzY0d2YjVMY3M2K0xZaUZtWmc0a3Z4dWptbm9tb0g3bFp1WGpsMApXM1NLQ0Y2Nno5YWpLMHQ1SFlDc0dOQXNmRjlsVlhOYlU1SU5peDVMbkc2NgotLS0tLUVORCBDRVJUSUZJQ0FURS0tLS0tCg==
    client-key-data: LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQpNSUlFb2dJQkFBS0NBUUVBdDRMbDZkWEI1RDBUZkNmN2xTR05rc2paRmNsYmFvZUlnTkhLbSs1NVI1aXZIQUN6CnVwSDNyeW5BMDFROVZxNTRkR0J0ZmdHUC80L3h4Sy9kNnduMFVnaFZUWnRnQWVtRGVPTXhVSTVsT3ZmbURvNkwKK2hQQjI1elpXZkhJbUdTSXF0ejVhMTJ6OVVEVDNZdUlqNlpobWFzOGhIK2tKNCszL1FMZzlKTy9KYWFQTkgvTwpKWGYzYktDd2JsaTAwQXZZUFdDMWtzbW1sS2ZSNWdKV1lySUl2NEh2Y3plWFVqWkE4K0Nnc0hSdktOWlkybjh6CkR0Y2ZBZkhIRGNBWU42YVZWQTg2SVMrYnNzZS9LVS82T1BHbXZRNktWM05qZ1FUTml6eldUU0FhTFJyRVZiVkcKa2gvQkQ4NkJTaW8yN2hwR3hrUHpBK2xCUCtsa1NLQXAzYUpyRHdJREFRQUJBb0lCQUZCbVdDYkgwVWdXL2pkeQpLUVpnaWU5YWNjbmF5Mk56OS9sQWNQMDZVUVp1UGFJT0tMQkFEWDAvMU15QjV0SFlaTXZRQjRpaVZKMktTa2w3Cko4WTNPVVRMZzl3Wmk4bXFya0JEZ2JLaWdIV0NjTmZGMmt2NVpnQzZ5bnRldEIwWVJzeGRQaVd0Q3hBVGsvOUgKaDlBdi9DamdYZ1pMQ2ZlUFB2UHAwL2N6MkJZOUVPTkhoOUt0UXNFN09zeEs0bXJOQUVPVFV3TzFtRS9vTmxjMQpUdXl3c2VETXVzZy9pZkRmeGc5V2VMbTVQUG8yT29ZWFhYcWhMd09ncDl5UCs3U3NKRk4ySmNSWGlhdWUyaTR3CitSUklva1dzSDRmM3l0cVBWYXBjSnZhWHJyYjg1TndIeFlRQzRSSWZWQmpabzRwTWN3eFpiRktkR0RocitZTDgKalRvWis2RUNnWUVBd1FZakhzcXBBL3AvbGNhZU5LbWVpZEMrUnlkQ1Rpdk5Va25Ba1c0Ym5HRkJvZGZFZGtCVQpNMWpxY1BGamdzb3l4eDZsbW1aZy9vK0dvVEFOUmVLaG1xN1o0d0NsQzUySHU4SHk1ZEU0QUpwSWZJUnl4NUhyCm1DbkxRQ1l4SDU4SnJVVFVpRkFza0VSZ2FhS3lvUExIV29jNVk5c3luckg0OEdKTzBQN2VJTEVDZ1lFQTgySTkKVHkyS3drZVRBT1NKaVpoQ3JlR0VBNktLOU1EQ1ExZzI2S0NzM2tmOTYyOXdPSTh5aTdmNEVUTHlBOHZrUHp1YgpGUmlpWitpd20xSXo5THQvei9nRjhSbFg3Z1RKYXJPOE0wQnErczZCdG1DRk5QRzFpVnBDV1AzbjgwaFc4Q0dXCjVjR3poYUR4VGZvSHJnNFZPT1c2TFZXVlFYQlBiTGJBVkZPQ043OENnWUJETlVMWFB0TTRxbWp3R3BjTldSMzEKZUhRNFRDZ2ZGY3RJNHBzbFNBUmZIOUg5YXlaaDBpWS9OcTl5b2VuM0tUWWk5TDNPaytVajNZK1A0aTVNN2dzOAowN0xVQW01MUsrV043NHNHa0NHQ3ZEV08vWU1Gai81TEhncENETW8vNjEwd01tNGFCR2h2MXc4RzJQcC9aZWtaCjBVbWZSanhLMjBjRlZBV0RhYXFvRVFLQmdEUW11ZEpzaE00cWZoSno1aERJd29qMXlNN3FsbkhwbC9iTVFUL0oKcGlFZk5nYXI0MVVMUWg1ME5rQ2hOUUNoUVBCWHVseGo0ZkQ0Q0ZmUDNuZ3pjU2pFRWFuZTcxdCtSUmFMR3VtMApoUGZuSmg1SlFtSGM1VFJnVmRVeDJ2RGpjRldXTFBwZ2JqSlZFVC9QTXJRV0ttLzlzYzRqQjQ5MUhGL0VMU1FrCm5NT0xBb0dBU2lQWWQzNS8vZ0VwMnpFK2RjMEVUVDFzY0hxYyt1dXRTQ2NxWnFiYkhpK2JlMDRUclIxVnZvOEkKcTlRSUd3SkROV3lZRm05RXByZjJpRVc2VkQzVTQ5czFORjlQTC9ENHZjMGxTS0RtaE1ReldRZDhWMUZsMnJYWApaQzZjYmhiR2tqODZQWnllTU1zNnlLaWRjZnpaYXNlRndvTmI4SVJqM2pUYWNSalZjbGM9Ci0tLS0tRU5EIFJTQSBQUklWQVRFIEtFWS0tLS0tCg==
[root@linux-node1 src]# 
```

8.使用kubectl工具
```
[root@linux-node1 ~]# kubectl get cs
NAME                 STATUS    MESSAGE             ERROR
controller-manager   Healthy   ok                  
scheduler            Healthy   ok                  
etcd-1               Healthy   {"health":"true"}   
etcd-2               Healthy   {"health":"true"}   
etcd-0               Healthy   {"health":"true"}   
```
