# 1、rbac.yaml

首先，为安全起见我们这里使用 RBAC 安全认证方式：(rbac.yaml)

```
mkdir -p /data/components/ingress

cat > /data/components/ingress/rbac.yaml << \EOF
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: traefik-ingress-controller
  namespace: kube-system
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: traefik-ingress-controller
rules:
  - apiGroups:
      - ""
    resources:
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
apiVersion: rbac.authorization.k8s.io/v1beta1
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
EOF

kubectl create -f /data/components/ingress/rbac.yaml
```

# 2、traefik.yaml

然后使用 Deployment 来管理 Pod，直接使用官方的 traefik 镜像部署即可（traefik.yaml）
```
cat > /data/components/ingress/traefik.yaml << \EOF
---
kind: Deployment
apiVersion: extensions/v1beta1
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
      tolerations:
      - operator: "Exists"
      nodeSelector:
        kubernetes.io/hostname: linux-node1.example.com  #默认master是不允许被调度的，加上tolerations后允许被调度
      containers:
      - image: traefik
        name: traefik-ingress-lb
        ports:
        - name: http
          containerPort: 80
        - name: admin
          containerPort: 8080
        args:
        - --api
        - --kubernetes
        - --logLevel=INFO
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
      port: 80
      name: web
    - protocol: TCP
      port: 8080
      name: admin
  type: NodePort
EOF

kubectl create -f /data/components/ingress/traefik.yaml

kubectl apply -f /data/components/ingress/traefik.yaml
```
```
要注意上面 yaml 文件:
tolerations:
- operator: "Exists"
nodeSelector:
  kubernetes.io/hostname: master
  
由于我们这里的特殊性，只有 master 节点有外网访问权限，所以我们使用nodeSelector标签将traefik的固定调度到master这个节点上，那么上面的tolerations是干什么的呢？这个是因为我们集群使用的 kubeadm 安装的，master 节点默认是不能被普通应用调度的，要被调度的话就需要添加这里的 tolerations 属性，当然如果你的集群和我们的不太一样，直接去掉这里的调度策略就行。

nodeSelector 和 tolerations 都属于 Pod 的调度策略，在后面的课程中会为大家讲解。

```
# 3、traefik-ui

traefik 还提供了一个 web ui 工具，就是上面的 8080 端口对应的服务，为了能够访问到该服务，我们这里将服务设置成的 NodePort

```
root># kubectl get pods -n kube-system -l k8s-app=traefik-ingress-lb -o wide
NAME                                          READY   STATUS    RESTARTS   AGE   IP           NODE                      NOMINATED NODE   READINESS GATES
traefik-ingress-controller-7bf58d448c-wcfbg   1/1     Running   0          14m   10.244.1.6   linux-node2.example.com   <none>           <none>

linux-node1.example.com<2019-09-04 22:05:11> ~
root># kubectl get svc -n kube-system
NAME                      TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                       AGE
......
traefik-ingress-service   NodePort    10.111.2.122    <none>        80:32327/TCP,8080:32303/TCP   20m
......
...

现在在浏览器中输入 master_node_ip:32303 就可以访问到 traefik 的 dashboard 了
```
http://192.168.56.12:32303/dashboard/

