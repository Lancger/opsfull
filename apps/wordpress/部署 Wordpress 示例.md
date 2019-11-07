# 一、简述

&#8195;Wordpress应用主要涉及到两个镜像：wordpress 和 mysql，wordpress 是应用的核心程序，mysql 是用于数据存储的。现在我们来看看如何来部署我们的这个wordpress应用。这个服务主要有2个pod资源，优先使用Deployment来管理我们的Pod。

# 二、创建一个MySQL的Deployment对象

- 1、创建namespace空间,并使用Service暴露服务给集群内部使用

```bash
# 创建blog命名空间
kubectl create namespace blog

# 清理wordpress-db资源
kubectl delete -f wordpress-db.yaml

# 编写mysql的deployment文件
cat > wordpress-db.yaml <<\EOF
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
  name: mysql
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
$ kubectl describe svc mysql -n blog
Name:              mysql
Namespace:         blog
Labels:            <none>
Annotations:       <none>
Selector:          app=mysql
Type:              ClusterIP
IP:                10.111.154.250
Port:              mysqlport  3306/TCP
TargetPort:        dbport/TCP
Endpoints:         10.244.1.98:3306
Session Affinity:  None
Events:            <none>
```

参考文档：

https://www.qikqiak.com/k8s-book/docs/31.%E9%83%A8%E7%BD%B2%20Wordpress%20%E7%A4%BA%E4%BE%8B.html   
