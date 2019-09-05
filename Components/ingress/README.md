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
traefik-ingress-controller-5b58d5c998-6dn97   1/1     Running   0          88s   10.244.0.2   linux-node1.example.com   <none>           <none>

root># kubectl get svc -n kube-system|grep traefik-ingress-service
traefik-ingress-service   NodePort    10.102.214.49   <none>        80:32472/TCP,8080:32482/TCP   44s

现在在浏览器中输入 master_node_ip:32303 就可以访问到 traefik 的 dashboard 了
```
http://192.168.56.11:32482/dashboard/

# 4、Ingress 对象

现在我们是通过 NodePort 来访问 traefik 的 Dashboard 的，那怎样通过 ingress 来访问呢？ 首先，需要创建一个 ingress 对象：(ingress.yaml)

```
cat > /data/components/ingress/ingress.yaml <<\EOF
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: traefik-web-ui
  namespace: kube-system
  annotations:
    kubernetes.io/ingress.class: traefik
spec:
  rules:
  - host: traefik.k8s.com
    http:
      paths:
      - backend:
          serviceName: traefik-ingress-service
          #servicePort: 8080
          servicePort: admin  #这里建议使用servicePort: admin,这样就避免端口的调整
EOF

kubectl create -f /data/components/ingress/ingress.yaml
kubectl apply -f /data/components/ingress/ingress.yaml

要注意上面的 ingress 对象的规则，特别是 rules 区域，我们这里是要为 traefik 的 dashboard 建立一个 ingress 对象，所以这里的 serviceName 对应的是上面我们创建的 traefik-ingress-service，端口也要注意对应 8080 端口，为了避免端口更改，这里的 servicePort 的值也可以替换成上面定义的 port 的名字：admin
```
创建完成后，我们应该怎么来测试呢？

```
第一步，在本地的/etc/hosts里面添加上 traefik.k8s.com 与 master 节点外网 IP 的映射关系

第二步，在浏览器中访问：http://traefik.k8s.com 我们会发现并没有得到我们期望的 dashboard 界面，这是因为我们上面部署 traefik 的时候使用的是 NodePort 这种 Service 对象，所以我们只能通过上面的 32482 端口访问到我们的目标对象：http://traefik.k8s.com:32482

加上端口后我们发现可以访问到 dashboard 了，而且在 dashboard 当中多了一条记录，正是上面我们创建的 ingress 对象的数据，我们还可以切换到 HEALTH 界面中，可以查看当前 traefik 代理的服务的整体的健康状态 

第三步，上面我们可以通过自定义域名加上端口可以访问我们的服务了，但是我们平时服务别人的服务是不是都是直接用的域名啊，http 或者 https 的，几乎很少有在域名后面加上端口访问的吧？为什么？太麻烦啊，端口也记不住，要解决这个问题，怎么办，我们只需要把我们上面的 traefik 的核心应用的端口隐射到 master 节点上的 80 端口，是不是就可以了，因为 http 默认就是访问 80 端口，但是我们在 Service 里面是添加的一个 NodePort 类型的服务，没办法映射 80 端口，怎么办？这里就可以直接在 Pod 中指定一个 hostPort 即可，更改上面的 traefik.yaml 文件中的容器端口：

containers:
- image: traefik
name: traefik-ingress-lb
ports:
- name: http
  containerPort: 80
  hostPort: 80      #新增这行
- name: admin
  containerPort: 8080
  
添加以后hostPort: 80，然后更新应用
kubectl apply -f traefik.yaml

更新完成后，这个时候我们在浏览器中直接使用域名方法测试下
http://traefik.k8s.com

第四步，正常来说，我们如果有自己的域名，我们可以将我们的域名添加一条 DNS 记录，解析到 master 的外网 IP 上面，这样任何人都可以通过域名来访问我的暴露的服务了。

如果你有多个边缘节点的话，可以在每个边缘节点上部署一个 ingress-controller 服务，然后在边缘节点前面挂一个负载均衡器，比如 nginx，将所有的边缘节点均作为这个负载均衡器的后端，这样就可以实现 ingress-controller 的高可用和负载均衡了。
```
