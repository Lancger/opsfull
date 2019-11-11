# 一、简述

&#8195;Wordpress应用主要涉及到两个镜像：wordpress 和 mysql，wordpress 是应用的核心程序，mysql 是用于数据存储的。现在我们来看看如何来部署我们的这个wordpress应用。这个服务主要有2个pod资源，优先使用Deployment来管理我们的Pod。

# 二、创建一个MySQL的Deployment对象

- 1、创建namespace空间,并使用Service暴露服务给集群内部使用

```bash
# 清理wordpress-db资源
kubectl delete -f wordpress-db.yaml

# 编写mysql的deployment文件
cat > wordpress-db.yaml <<\EOF
---
apiVersion: v1
kind: Namespace
metadata:
  name: blog

---
apiVersion: apps/v1beta1
kind: Deployment
metadata:
  name: mysql-deploy
  namespace: blog
  labels:
    app: mysql
spec:
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:5.7
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 3306
          name: dbport
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: rootPassW0rd
        - name: MYSQL_DATABASE
          value: wordpress
        - name: MYSQL_USER
          value: wordpress
        - name: MYSQL_PASSWORD
          value: wordpress
        volumeMounts:
        - name: db
          mountPath: /var/lib/mysql
      volumes:
      - name: db
        hostPath:
          path: /var/lib/mysql

---
apiVersion: v1
kind: Service
metadata:
  name: wordpress-mysql
  namespace: blog
spec:
  selector:
    app: mysql
  ports:
  - name: mysqlport
    protocol: TCP
    port: 3306
    targetPort: dbport
EOF

# 创建资源和服务
kubectl create -f wordpress-db.yaml
```

- 2、查看创建的svc服务

```bash
$ kubectl describe svc wordpress-mysql -n blog
Name:              wordpress-mysql
Namespace:         blog
Labels:            <none>
Annotations:       <none>
Selector:          app=mysql
Type:              ClusterIP
IP:                10.104.88.234
Port:              mysqlport  3306/TCP
TargetPort:        dbport/TCP
Endpoints:         10.244.1.115:3306
Session Affinity:  None
Events:            <none>
```

- 3、验证创建的mysql资源服务可用性

```bash
# 命令行跑一个centos7的bash基础容器
$ kubectl run mysql-test --rm -it --image=alpine /bin/sh
kubectl run centos7-app --rm -it --image=centos:7.2.1511 -n blog

# 进入到容器
kubectl exec `kubectl get pods -n blog|grep centos7-app|awk '{print $1}'` -it /bin/bash -n blog

# 安装mysql客户端
yum install vim net-tools telnet nc -y
yum install -y mariadb.x86_64 mariadb-libs.x86_64

# 测试mysql服务端口是否OK
nc -zv wordpress-mysql 3306

# 连接测试
mysql -h'wordpress-mysql' -u'root' -p'rootPassW0rd'  # 这里使用域名测试

mysql -h'10.104.88.234' -u'root' -p'rootPassW0rd'   # 这里使用集群IP测试，这个经常会变

mysql -h'10.244.1.115' -u'root' -p'rootPassW0rd'   # 这里使用Endpoints IP测试,这个经常会变
```

# 三、创建Wordpress服务Deployment对象

```bash
# 清理wordpress资源
kubectl delete -f wordpress.yaml

# 编写wordpress的deployment文件
cat > wordpress.yaml <<\EOF
---
apiVersion: apps/v1beta1
kind: Deployment
metadata:
  name: wordpress-deploy
  namespace: blog
  labels:
    app: wordpress
spec:
  template:
    metadata:
      labels:
        app: wordpress
    spec:
      containers:
      - name: wordpress
        image: wordpress
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
          name: wdport
        env:
        - name: WORDPRESS_DB_HOST
          value: wordpress-mysql:3306
        - name: WORDPRESS_DB_USER
          value: wordpress
        - name: WORDPRESS_DB_PASSWORD
          value: wordpress

---
apiVersion: v1
kind: Service
metadata:
  name: wordpress-service
  namespace: blog
spec:
  type: NodePort
  selector:
    app: wordpress
  ports:
  - name: wordpressport
    protocol: TCP
    port: 80
    targetPort: wdport
    nodePort: 32380     #新增这一行，指定固定node端口
EOF

# 创建资源和服务
kubectl create -f wordpress.yaml

# 查看创建的pod资源
kubectl get pods -n blog

# 查看创建的svc资源
kubectl get svc -n blog

NAME                TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
wordpress-mysql     ClusterIP   10.104.88.234    <none>        3306/TCP       3m36s
wordpress-service   NodePort    10.111.212.108   <none>        80:32380/TCP   12s
```

# 四、访问测试

```bash
#可以看到wordpress服务产生了一个32380的端口，现在我们是不是就可以通过任意节点的NodeIP加上32255端口，就可以访问我们的wordpress应用了，在浏览器中打开，如果看到wordpress跳转到了安装页面，证明我们的嗯安装是没有任何问题的了，如果没有出现预期的效果，那么就需要去查看下Pod的日志来查看问题了：

http://192.168.56.11:32380/
```

![wordpress](https://github.com/Lancger/opsfull/blob/master/images/wordpress-01.png)


# 五、提高稳定性（进阶）

`1、当你使用kuberentes的时候，有没有遇到过Pod在启动后一会就挂掉然后又重新启动这样的恶性循环？你有没有想过kubernetes是如何检测pod是否还存活？虽然容器已经启动，但是kubernetes如何知道容器的进程是否准备好对外提供服务了呢？让我们通过kuberentes官网的这篇文章[Configure Liveness and Readiness Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)，来一探究竟。`

`2、Kubelet使用liveness probe（存活探针）来确定何时重启容器。例如，当应用程序处于运行状态但无法做进一步操作，liveness探针将捕获到deadlock，重启处于该状态下的容器，使应用程序在存在bug的情况下依然能够继续运行下去（谁的程序还没几个bug呢）。`

`3、Kubelet使用readiness probe（就绪探针）来确定容器是否已经就绪可以接受流量。只有当Pod中的容器都处于就绪状态时kubelet才会认定该Pod处于就绪状态。该信号的作用是控制哪些Pod应该作为service的后端。如果Pod处于非就绪状态，那么它们将会被从service的load balancer中移除。`
`

现在wordpress应用已经部署成功了，那么就万事大吉了吗？如果我们的网站访问量突然变大了怎么办，如果我们要更新我们的镜像该怎么办？如果我们的mysql服务挂掉了怎么办？

所以要保证我们的网站能够非常稳定的提供服务，我们做得还不够，我们可以通过做些什么事情来提高网站的稳定性呢？

## 第一. 增加健康检测

我们前面说过liveness probe和rediness probe是提高应用稳定性非常重要的方法:

```bash
livenessProbe:
  tcpSocket:
    port: 80
  initialDelaySeconds: 3
  periodSeconds: 3
readinessProbe:
  tcpSocket:
    port: 80
  initialDelaySeconds: 5
  periodSeconds: 10

#增加上面两个探针，每10s检测一次应用是否可读，每3s检测一次应用是否存活
```

## 第二. 增加 HPA

让我们的应用能够自动应对流量高峰期：

```bash
1、创建HPA资源（一定要设置Pod的资源限制参数: request, 否则HPA不会工作）

$ kubectl autoscale deployment wordpress-deploy --cpu-percent=10 --min=1 --max=10 -n blog

deployment "wordpress-deploy" autoscaled

# 我们用kubectl autoscale命令为我们的wordpress-deploy创建一个HPA对象，最小的 pod 副本数为1，最大为10，HPA会根据设定的 cpu使用率（10%）动态的增加或者减少pod数量。当然最好我们也为Pod声明一些资源限制：

resources:
  limits:
    cpu: 200m
    memory: 200Mi
  requests:
    cpu: 100m
    memory: 100Mi
    
# 查看HPA
$ kubectl get HorizontalPodAutoscaler -A 
NAMESPACE   NAME               REFERENCE                     TARGETS         MINPODS   MAXPODS   REPLICAS   AGE
blog        wordpress-deploy   Deployment/wordpress-deploy   <unknown>/10%   1         10        1          4m19s

2、更新Deployment后，我们可以可以来测试下上面的HPA是否会生效：
$ kubectl run -i --tty load-generator --image=busybox /bin/sh

If you don't see a command prompt, try pressing enter.

while true; do wget -q -O- http://wordpress:80; done

3、观察Deployment的副本数是否有变化
$ kubectl get deployment wordpress-deploy

NAME        DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
wordpress-deploy   3         3         3            3           4d

4、删除HPA
$ kubectl delete HorizontalPodAutoscaler  wordpress-deploy -n blog

horizontalpodautoscaler.autoscaling "wordpress-deploy" deleted
```

## 第三. 增加滚动更新策略

这样可以保证我们在更新应用的时候服务不会被中断：

```bash
replicas: 2
revisionHistoryLimit: 10
minReadySeconds: 5
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 1
```

## 第四. 使用Service的名称来代替host

`如果mysql服务被重新创建了的话，它的clusterIP非常有可能就变化了，所以上面我们环境变量中的WORDPRESS_DB_HOST的值就会有问题，就会导致访问不了数据库服务了，这个地方我们可以直接使用Service的名称来代替host，这样即使clusterIP变化了，也不会有任何影响，这个我们会在后面的服务发现的章节和大家深入讲解的`

```bash
env:
- name: WORDPRESS_DB_HOST
  value: mysql-wordpress-production:3306
```

## 第五. 容器启动顺序

`在部署wordpress服务的时候，mysql服务以前启动起来了吗？如果没有启动起来是不是我们也没办法连接数据库了啊？该怎么办，是不是在启动wordpress应用之前应该去检查一下mysql服务，如果服务正常的话我们就开始部署应用了，这是不是就是InitContainer的用法`

```bash
initContainers:
- name: init-db
  image: busybox
  command: ['sh', '-c', 'until nslookup mysql; do echo waiting for mysql service; sleep 2; done;']
  
# 直到mysql服务创建完成后，initContainer才结束，结束完成后我们才开始下面的部署。
```

# 六、优化文件合并

```bash
kubectl delete -f wordpress-all.yaml

cat > wordpress-all.yaml <<\EOF
---
apiVersion: v1
kind: Namespace
metadata:
  name: blog

---
apiVersion: apps/v1beta1
kind: Deployment
metadata:
  name: mysql-deploy
  namespace: blog
  labels:
    app: mysql
spec:
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:5.7
        ports:
        - containerPort: 3306
          name: dbport
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: rootPassW0rd
        - name: MYSQL_DATABASE
          value: wordpress
        - name: MYSQL_USER
          value: wordpress
        - name: MYSQL_PASSWORD
          value: wordpress
        volumeMounts:
        - name: db
          mountPath: /var/lib/mysql
      volumes:
      - name: db
        hostPath:
          path: /var/lib/mysql

---
apiVersion: v1
kind: Service
metadata:
  name: wordpress-mysql
  namespace: blog
spec:
  selector:
    app: mysql
  ports:
  - name: mysqlport
    protocol: TCP
    port: 3306
    targetPort: dbport

---
apiVersion: apps/v1beta1
kind: Deployment
metadata:
  name: wordpress-deploy
  namespace: blog
  labels:
    app: wordpress
spec:
  revisionHistoryLimit: 10
  minReadySeconds: 5
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  template:
    metadata:
      labels:
        app: wordpress
    spec:
      initContainers:
      - name: init-db
        image: busybox
        command: ['sh', '-c', 'until nslookup wordpress-mysql; do echo waiting for mysql service; sleep 2; done;']
      containers:
      - name: wordpress
        image: wordpress
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 80
          name: wdport
        env:
        - name: WORDPRESS_DB_HOST
          value: mysql:3306
        - name: WORDPRESS_DB_USER
          value: wordpress
        - name: WORDPRESS_DB_PASSWORD
          value: wordpress
        resources:
          limits:
            cpu: 200m
            memory: 200Mi
          requests:
            cpu: 100m
            memory: 100Mi

---
apiVersion: v1
kind: Service
metadata:
  name: wordpress
  namespace: blog
spec:
  selector:
    app: wordpress
  type: NodePort
  ports:
  - name: wordpressport
    protocol: TCP
    port: 80
    nodePort: 32380
    targetPort: wdport
EOF

kubectl apply -f wordpress-all.yaml

watch kubectl get pods -n blog
```

参考文档：

https://www.qikqiak.com/k8s-book/docs/31.%E9%83%A8%E7%BD%B2%20Wordpress%20%E7%A4%BA%E4%BE%8B.html   

https://blog.csdn.net/maoreyou/article/details/80050623  Kubernetes之路 3 - 解决服务依赖
