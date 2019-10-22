# 一、安装dashboard v1.10.1

## 1、使用NodePort方式暴露访问

1、下载对应的yaml文件
```
wget https://raw.githubusercontent.com/kubernetes/dashboard/v1.10.1/src/deploy/recommended/kubernetes-dashboard.yaml

vim kubernetes-dashboard.yaml

1、# 修改镜像名称
......
    spec:
      containers:
      - name: kubernetes-dashboard
        #image: k8s.gcr.io/kubernetes-dashboard-amd64:v1.10.1 #这个换成阿里云的镜像
        image: registry.cn-hangzhou.aliyuncs.com/google_containers/kubernetes-dashboard-amd64:v1.10.1
        ports:
        - containerPort: 8443
          protocol: TCP
        args:
          - --auto-generate-certificates
......
```

2、# 修改Service为NodePort类型
```
......
kind: Service
apiVersion: v1
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kube-system
spec:
  type: NodePort   # 新增这一行，指定为NodePort方式
  ports:
    - port: 443
      targetPort: 8443
      nodePort: 32370  #新增这一行，指定固定node端口
  selector:
    k8s-app: kubernetes-dashboard
```

3、dashboard最终文件

```
cat > kubernetes-dashboard.yaml << \EOF
# Copyright 2017 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# ------------------- Dashboard Secret ------------------- #

apiVersion: v1
kind: Secret
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard-certs
  namespace: kube-system
type: Opaque

---
# ------------------- Dashboard Service Account ------------------- #

apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kube-system

---
# ------------------- Dashboard Role & Role Binding ------------------- #

kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: kubernetes-dashboard-minimal
  namespace: kube-system
rules:
  # Allow Dashboard to create 'kubernetes-dashboard-key-holder' secret.
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["create"]
  # Allow Dashboard to create 'kubernetes-dashboard-settings' config map.
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["create"]
  # Allow Dashboard to get, update and delete Dashboard exclusive secrets.
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["kubernetes-dashboard-key-holder", "kubernetes-dashboard-certs"]
  verbs: ["get", "update", "delete"]
  # Allow Dashboard to get and update 'kubernetes-dashboard-settings' config map.
- apiGroups: [""]
  resources: ["configmaps"]
  resourceNames: ["kubernetes-dashboard-settings"]
  verbs: ["get", "update"]
  # Allow Dashboard to get metrics from heapster.
- apiGroups: [""]
  resources: ["services"]
  resourceNames: ["heapster"]
  verbs: ["proxy"]
- apiGroups: [""]
  resources: ["services/proxy"]
  resourceNames: ["heapster", "http:heapster:", "https:heapster:"]
  verbs: ["get"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: kubernetes-dashboard-minimal
  namespace: kube-system
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: kubernetes-dashboard-minimal
subjects:
- kind: ServiceAccount
  name: kubernetes-dashboard
  namespace: kube-system

---
# ------------------- Dashboard Deployment ------------------- #

kind: Deployment
apiVersion: apps/v1
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kube-system
spec:
  replicas: 1
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      k8s-app: kubernetes-dashboard
  template:
    metadata:
      labels:
        k8s-app: kubernetes-dashboard
    spec:
      containers:
      - name: kubernetes-dashboard
        #image: k8s.gcr.io/kubernetes-dashboard-amd64:v1.10.1
        image: registry.cn-hangzhou.aliyuncs.com/google_containers/kubernetes-dashboard-amd64:v1.10.1
        ports:
        - containerPort: 8443
          protocol: TCP
        args:
          - --auto-generate-certificates
          # Uncomment the following line to manually specify Kubernetes API server Host
          # If not specified, Dashboard will attempt to auto discover the API server and connect
          # to it. Uncomment only if the default does not work.
          # - --apiserver-host=http://my-address:port
        volumeMounts:
        - name: kubernetes-dashboard-certs
          mountPath: /certs
          # Create on-disk volume to store exec logs
        - mountPath: /tmp
          name: tmp-volume
        livenessProbe:
          httpGet:
            scheme: HTTPS
            path: /
            port: 8443
          initialDelaySeconds: 30
          timeoutSeconds: 30
      volumes:
      - name: kubernetes-dashboard-certs
        secret:
          secretName: kubernetes-dashboard-certs
      - name: tmp-volume
        emptyDir: {}
      serviceAccountName: kubernetes-dashboard
      # Comment the following tolerations if Dashboard must not be deployed on master
      tolerations:
      - key: node-role.kubernetes.io/master
        effect: NoSchedule

---
# ------------------- Dashboard Service ------------------- #

kind: Service
apiVersion: v1
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kube-system
spec:
  type: NodePort  # 新增这一行，指定为NodePort方式
  ports:
    - port: 443
      targetPort: 8443
      nodePort: 32370  #新增这一行，指定固定node端口
  selector:
    k8s-app: kubernetes-dashboard
EOF

kubectl apply -f kubernetes-dashboard.yaml
```

4、然后创建一个具有全局所有权限的用户来登录Dashboard：(admin.yaml)
```
cat > admin.yaml << \EOF
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: admin
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: ServiceAccount
  name: admin
  namespace: kube-system

---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin
  namespace: kube-system
  labels:
    kubernetes.io/cluster-service: "true"
    addonmanager.kubernetes.io/mode: Reconcile
EOF

kubectl apply -f admin.yaml

kubectl delete -f admin.yaml

#获取token
kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep admin | awk '{print $1}')
```
5、访问测试 `https://nodeip:32370`


## 2、使用Ingress方式访问

```bash
#清理NodePort方式的dashboard
kubectl delete -f kubernetes-dashboard.yaml

rm -f kubernetes-dashboard.yaml

wget https://raw.githubusercontent.com/kubernetes/dashboard/v1.10.1/src/deploy/recommended/kubernetes-dashboard.yaml

kubectl apply -n kube-system -f kubernetes-dashboard.yaml
```

1、创建和安装加密访问凭证

通过https进行访问必需要使用证书和密钥，在Kubernetes中可以通过配置一个加密凭证（TLS secret）来提供。

```bash
#1、创建 tls secret

#这里只是拿来自己使用，创建一个自己签名的证书。如果是公共服务，建议去数字证书颁发机构去申请一个正式的数字证书（需要一些服务费用）；或者使用Let's encrypt去申请一个免费的（后面有介绍）；如果使用Cloudflare可以自动生成证书和https转接服务，但是需要将域名迁移过去，高级功能是收费的。
#https://github.com/kubernetes/contrib/blob/master/ingress/controllers/nginx/examples/tls/README.md

mkdir -p /etc/certs/ssl/
cd /etc/certs/ssl/
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ./tls.key -out ./tls.crt -subj "/CN=dashboard.devops.com"

#将会产生两个文件tls.key和tls.crt，你可以改成自己的文件名或放在特定的目录下（如果你是为公共服务器创建的，请保证这个不会被别人访问到）。后面的192.168.56.11是我的服务器IP地址，你可以改成自己的。
```
2、安装 tls secret

```bash
#下一步，将这两个文件的信息创建为一个Kubernetes的secret访问凭证，我将名称指定为 k8s-dashboard-secret ，这在后面的Ingress配置时将会用到。如果你修改了这个名字，注意后面的Ingress配置yaml文件也需要同步修改。

kubectl -n kube-system delete secret k8s-dashboard-secret

kubectl -n kube-system create secret tls k8s-dashboard-secret --key /etc/certs/tls.key --cert /etc/certs/tls.crt

#注意：
    #上面命令的参数 -n 指定凭证安装的命名空间。
    #为了安全考虑，Ingress所有的资源（凭证、路由、服务）必须在同一个命名空间。
```

3、配置Ingress 路由

```bash
#将下面的内容保存为文件dashboard-ingress.yaml。里面的 / 设定为访问Kubernetes dashboard服务，/web 只是为了测试和占位，如果没有安装nginx，将会返回找不到服务的消息。

cat >dashboard-ingress.yaml<<\EOF
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: k8s-dashboard
  namespace: kube-system
  annotations:
    kubernetes.io/ingress.class: traefik
spec:
  tls:
   - secretName: k8s-dashboard-secret
  rules:
   - host: dashboard.devops.com
     http:
      paths:
      - path: /
        backend:
          serviceName: kubernetes-dashboard
          servicePort: 443
      - path: /web
EOF

kubectl apply -n kube-system -f dashboard-ingress.yaml

#注意
    #上面的annotations部分是必须的，以提供https和https service的支持。不过，不同的Ingress Controller可能的实现（或版本）有所不同，需要安装相应的实现（版本）进行设置。
    
    #参见，#issue:https://github.com/kubernetes/ingress-nginx/issues/2460
```


参考资料：

https://my.oschina.net/u/2306127/blog/1930169?from=timeline&isappinstalled=0  Kubernetes dashboard 通过 Ingress 提供HTTPS访问
