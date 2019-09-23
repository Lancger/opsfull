# 证书文件

1、生成证书
```
mkdir -p /ssl/{default,first,second}
cd /ssl/default/
openssl req -x509 -nodes -days 165 -newkey rsa:2048 -keyout tls_default.key -out tls_default.crt -subj "/CN=k8s.test.com"
kubectl -n kube-system create secret tls traefik-cert --key=tls_default.key --cert=tls_default.crt

cd /ssl/first/
openssl req -x509 -nodes -days 265 -newkey rsa:2048 -keyout tls_first.key -out tls_first.crt -subj "/CN=k8s.first.com"
kubectl -n kube-system create secret tls first-k8s --key=tls_first.key --cert=tls_first.crt

cd /ssl/second/
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls_second.key -out tls_second.crt -subj "/CN=k8s.second.com"
kubectl -n kube-system create secret tls second-k8s --key=tls_second.key --cert=tls_second.crt

#查看证书
kubectl get secret traefik-cert first-k8s second-k8s -n kube-system
kubectl describe secret traefik-cert first-k8s second-k8s -n kube-system
```

2、删除证书

```
$ kubectl delete secret traefik-cert first-k8s second-k8s -n kube-system

secret "second-k8s" deleted
secret "traefik-cert" deleted
secret "first-k8s" deleted
```

# 证书配置

1、创建configMap(cm)

```
mkdir -p /config/
cd /config/

$  vim traefik.toml
defaultEntryPoints = ["http", "https"]
[entryPoints]
  [entryPoints.http]
    address = ":80"
  [entryPoints.https]
    address = ":443"
    [entryPoints.https.tls]
      [[entryPoints.https.tls.certificates]]
        CertFile = "/ssl/default/tls_default.crt"
        KeyFile = "/ssl/default/tls_default.key"
      [[entryPoints.https.tls.certificates]]
        CertFile = "/ssl/first/tls_first.crt"
        KeyFile = "/ssl/first/tls_first.key"
      [[entryPoints.https.tls.certificates]]
        CertFile = "/ssl/second/tls_second.crt"
        KeyFile = "/ssl/second/tls_second.key"
        
$ kubectl create configmap traefik-conf --from-file=traefik.toml -n kube-system

$ kubectl get configmap traefik-conf -n kube-system

$ kubectl describe cm traefik-conf -n kube-system
```
2、删除configMap(cm)

```
$ kubectl delete cm traefik-conf -n kube-system
```

# traefik-ingress-controller文件

1、创建文件
```
$ vim traefik-controller-tls.yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: traefik-conf
  namespace: kube-system
data:
  traefik.toml: |
    insecureSkipVerify = true
    defaultEntryPoints = ["http", "https"]
    [entryPoints]
      [entryPoints.http]
        address = ":80"
      [entryPoints.https]
        address = ":443"
        [entryPoints.https.tls]
          [[entryPoints.https.tls.certificates]]
            CertFile = "/ssl/default/tls.crt"
            KeyFile = "/ssl/default/tls.key"
          [[entryPoints.https.tls.certificates]]
            CertFile = "/ssl/first/tls_first.crt"
            KeyFile = "/ssl/first/tls_first.key"
          [[entryPoints.https.tls.certificates]]
            CertFile = "/ssl/second/tls_second.crt"
            KeyFile = "/ssl/second/tls_second.key"
---
kind: Deployment
apiVersion: apps/v1beta1
metadata:
  name: traefik-ingress-controller
  namespace: kube-system
  labels:
    k8s-app: traefik-ingress-lb
spec:
  replicas: 1
  selector:
    matchLabels:
      k8s-app: traefik-ingress-lb
  template:
    metadata:
      labels:
        k8s-app: traefik-ingress-lb
        name: traefik-ingress-lb
    spec:
      serviceAccountName: traefik-ingress-controller
      terminationGracePeriodSeconds: 60
      volumes:
      - name: ssl
        secret:
          secretName: traefik-cert
      - name: config
        configMap:
          name: traefik-conf
      #nodeSelector:
      #  node-role.kubernetes.io/traefik: "true"
      tolerations:
      - operator: "Exists"
      nodeSelector:
        kubernetes.io/hostname: 10.19.1.156    #指定traefik-ingress-controller跑在这个node节点上面
      containers:
      - image: traefik:v1.7.12
        imagePullPolicy: IfNotPresent
        name: traefik-ingress-lb
        volumeMounts:
        - mountPath: "/ssl"
          name: "ssl"
        - mountPath: "/config"
          name: "config"
        resources:
          limits:
            cpu: 1000m
            memory: 800Mi
          requests:
            cpu: 500m
            memory: 600Mi
        args:
        - --configfile=/config/traefik.toml
        - --api
        - --kubernetes
        - --logLevel=INFO
        securityContext:
          capabilities:
            drop:
              - ALL
            add:
              - NET_BIND_SERVICE
        ports:
          - name: http
            containerPort: 80
            hostPort: 80
          - name: https
            containerPort: 443
            hostPort: 443
---
kind: Service
apiVersion: v1
metadata:
  name: traefik-ingress-service
  namespace: kube-system
spec:
  selector:
    k8s-app: traefik-ingress-lb
  ports:
    - protocol: TCP
      # 该端口为 traefik ingress-controller的服务端口
      port: 80
      # 集群hosts文件中设置的 NODE_PORT_RANGE 作为 NodePort的可用范围
      # 从默认20000~40000之间选一个可用端口，让ingress-controller暴露给外部的访问
      nodePort: 23456
      name: http
    - protocol: TCP
      # 
      port: 443
      nodePort: 23457
      name: https
    - protocol: TCP
      # 该端口为 traefik 的管理WEB界面
      port: 8080
      name: admin
  type: NodePort
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: traefik-ingress-controller
rules:
  - apiGroups:
      - ""
    resources:
      - pods
      - services
      - endpoints
      - secrets
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - extensions
    resources:
      - ingresses
    verbs:
      - get
      - list
      - watch
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: traefik-ingress-controller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: traefik-ingress-controller
subjects:
- kind: ServiceAccount
  name: traefik-ingress-controller
  namespace: kube-system
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: traefik-ingress-controller
  namespace: kube-system
```

2、应用生效
```
$ kubectl apply -f traefik-controller-tls.yaml 

configmap/traefik-conf created
deployment.apps/traefik-ingress-controller created
service/traefik-ingress-service created
clusterrole.rbac.authorization.k8s.io/traefik-ingress-controller created
clusterrolebinding.rbac.authorization.k8s.io/traefik-ingress-controller created
serviceaccount/traefik-ingress-controller created

#删除资源
$ kubectl delete -f traefik-controller-tls.yaml 
```
# 命令行创建 https ingress 例子
```
# 创建示例应用
$ kubectl run test-hello --image=nginx:alpine --port=80 --expose -n kube-system

# hello-tls-ingress 示例
$ cd /config/
$ vim hello-tls.ing.yaml

apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: hello-tls-ingress
  namespace: kube-system
  annotations:
    kubernetes.io/ingress.class: traefik
spec:
  rules:
  - host: k8s.test.com
    http:
      paths:
      - backend:
          serviceName: test-hello
          servicePort: 80
  tls:
  - secretName: traefik-cert
  
# 创建https ingress
$ kubectl apply -f /config/hello-tls.ing.yaml

# 注意根据hello示例，需要在kube-system命名空间创建对应的secret: traefik-cert(这步在开篇已经创建了)
$ kubectl -n kube-system create secret tls traefik-cert --key=tls_default.key --cert=tls_default.crt

# 测试访问：
https://k8s.test.com:23457
```
  ![ingress测试](https://github.com/Lancger/opsfull/blob/master/images/ingress-k8s-02.png)

# 测试deployment和ingress
```
$ vim nginx-ingress-deploy.yaml
---
apiVersion: apps/v1beta1
kind: Deployment
metadata:
  name: nginx-deployment
  namespace: kube-system
spec:
  replicas: 2
  template:
    metadata:
      labels:
        app: nginx-pod
    spec:
      containers:
      - name: nginx
        image: nginx:1.15.5
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
  namespace: kube-system
  annotations:
    traefik.ingress.kubernetes.io/load-balancer-method: drr  #动态加权轮训调度
spec:
  template:
    metadata:
      labels:
        name: nginx-service
spec:
  selector:
    app: nginx-pod
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: nginx-ingress
  namespace: kube-system
  annotations:
    kubernetes.io/ingress.class: traefik
spec:
  tls:
  - secretName: first-k8s
  - secretName: second-k8s
  rules:
  - host: k8s.first.com
    http:
      paths:
      - backend:
          serviceName: nginx-service
          servicePort: 80
  - host: k8s.senond.com
    http:
      paths:
      - backend:
          serviceName: nginx-service
          servicePort: 80
          
$ kubectl apply -f nginx-ingress-deploy.yaml 
$ kubectl delete -f nginx-ingress-deploy.yaml 
```
