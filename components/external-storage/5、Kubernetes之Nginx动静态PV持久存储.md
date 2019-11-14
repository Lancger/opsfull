# 一、nginx使用nfs静态PV

## 1、静态nfs-static-nginx-rc.yaml

```bash
##清理资源
kubectl delete -f nfs-static-nginx-rc.yaml -n test

cat >nfs-static-nginx-rc.yaml<<\EOF
##创建namespace
---
apiVersion: v1
kind: Namespace
metadata:
   name: test
   labels:
     name: test
##创建nfs-pv
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs-pv
  labels:
    pv: nfs-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: nfs  # 注意这里使用nfs的storageClassName，如果没改k8s的默认storageClassName的话，这里可以省略
  nfs:
    path: /data/nfs/nginx/
    server: 10.198.1.155
##创建nfs-pvc
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: nfs-pvc
  namespace: test
  labels:
    pvc: nfs-pvc
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 10Gi
  storageClassName: nfs
  selector:
    matchLabels:
      pv: nfs-pv
##部署应用nginx
---
apiVersion: v1
kind: ReplicationController
metadata:
  name: nginx-test
  namespace: test
  labels:
    name: nginx-test
spec:
  replicas: 2
  selector:
    name: nginx-test
  template:
    metadata:
      labels:
       name: nginx-test
    spec:
      containers:
      - name: nginx-test
        image: docker.io/nginx
        volumeMounts:
        - mountPath: /usr/share/nginx/html
          name: nginx-data
        ports:
        - containerPort: 80
      volumes:
      - name: nginx-data
        persistentVolumeClaim:
          claimName: nfs-pvc
##创建service
---
apiVersion: v1
kind: Service
metadata:
  namespace: test
  name: nginx-test
  labels:
    name: nginx-test
spec:
  type: NodePort
  ports:
  - port: 80
    protocol: TCP
    targetPort: 80
    name: http
    nodePort: 30080
  selector:
    name: nginx-test
EOF

##创建资源
kubectl apply -f nfs-static-nginx-rc.yaml -n test

##查看pv资源
kubectl get pv -n test --show-labels

##查看pvc资源
kubectl get pvc -n test --show-labels

##查看pod
$ kubectl get pods -n test
NAME               READY   STATUS    RESTARTS   AGE
nginx-test-r4n2j   1/1     Running   0          54s
nginx-test-zstf5   1/1     Running   0          54s

#可以看到，nginx应用已经部署成功。
#nginx应用的数据目录是使用的nfs共享存储，我们在nfs共享的目录里加入index.html文件，然后再访问nginx-service暴露的端口
#切换到到nfs-server服务器上

echo "Test NFS Share discovery with nfs-static-nginx-rc" > /data/nfs/nginx/index.html

#在浏览器上访问kubernetes主节点的 http://master:30080，就能访问到这个页面内容了
```

## 2、静态nfs-static-nginx-deployment.yaml

```bash
##清理资源
kubectl delete -f nfs-static-nginx-deployment.yaml -n test

cat >nfs-static-nginx-deployment.yaml<<\EOF
##创建namespace
---
apiVersion: v1
kind: Namespace
metadata:
   name: test
   labels:
     name: test
##创建nfs-pv
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs-pv
  labels:
    pv: nfs-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: nfs  # 注意这里使用nfs的storageClassName，如果没改k8s的默认storageClassName的话，这里可以省略
  nfs:
    path: /data/nfs/nginx/
    server: 10.198.1.155
##创建nfs-pvc
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: nfs-pvc
  namespace: test
  labels:
    pvc: nfs-pvc
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 10Gi
  storageClassName: nfs
  selector:
    matchLabels:
      pv: nfs-pv
##部署应用nginx
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  namespace: test
  labels:
    name: nginx-test
spec:
  replicas: 2
  selector:
    matchLabels:
      name: nginx-test
  template:
    metadata:
      labels:
       name: nginx-test
    spec:
      containers:
      - name: nginx-test
        image: docker.io/nginx
        volumeMounts:
        - mountPath: /usr/share/nginx/html
          name: nginx-data
        ports:
        - containerPort: 80
      volumes:
      - name: nginx-data
        persistentVolumeClaim:
          claimName: nfs-pvc
##创建service
---
apiVersion: v1
kind: Service
metadata:
  namespace: test
  name: nginx-test
  labels:
    name: nginx-test
spec:
  type: NodePort
  ports:
  - port: 80
    protocol: TCP
    targetPort: 80
    name: http
    nodePort: 30080
  selector:
    name: nginx-test
EOF

##创建资源
kubectl apply -f nfs-static-nginx-deployment.yaml -n test

##查看pv资源
kubectl get pv -n test --show-labels

##查看pvc资源
kubectl get pvc -n test --show-labels

##查看pod
$ kubectl get pods -n test
NAME                                READY   STATUS    RESTARTS   AGE
nginx-deployment-64d6f78cdf-8bw8t   1/1     Running   0          55s
nginx-deployment-64d6f78cdf-n5n4q   1/1     Running   0          55s

#可以看到，nginx应用已经部署成功。
#nginx应用的数据目录是使用的nfs共享存储，我们在nfs共享的目录里加入index.html文件，然后再访问nginx-service暴露的端口
#切换到到nfs-server服务器上

echo "Test NFS Share discovery with nfs-static-nginx-deployment" > /data/nfs/nginx/index.html

#在浏览器上访问kubernetes主节点的 http://master:30080，就能访问到这个页面内容了
```

## 3、nginx多目录挂载

```
1、PV和PVC是一一对应关系，当有PV被某个PVC所占用时，会显示banding，其它PVC不能再使用绑定过的PV。

2、PVC一旦绑定PV，就相当于是一个存储卷，此时PVC可以被多个Pod所使用。（PVC支不支持被多个Pod访问，取决于访问模型accessMode的定义）。

3、PVC若没有找到合适的PV时，则会处于pending状态。

4、PV是属于集群级别的，不能定义在名称空间中。

5、PVC时属于名称空间级别的。
```

```bash
##清理资源
kubectl delete -f nfs-static-nginx-dp-many.yaml -n test

cat >nfs-static-nginx-dp-many.yaml<<\EOF
##创建namespace
---
apiVersion: v1
kind: Namespace
metadata:
   name: test
   labels:
     name: test
##创建nfs-pv
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs-pv
  labels:
    pv: nfs-pv
spec:
  capacity:
    storage: 200Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  storageClassName: nfs  # 注意这里使用nfs的storageClassName，如果没改k8s的默认storageClassName的话，这里可以省略
  nfs:
    path: /data/nfs/nginx/
    server: 10.19.1.155
##创建pvc名字为nfs-nginx-data,存放数据
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: nfs-nginx-data
  namespace: test
  labels:
    pvc: nfs-nginx-data
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 150Gi  #注意这2个pvc的总和大小，不能超过pv的大小
  storageClassName: nfs
  selector:
    matchLabels:
      pv: nfs-pv
##创建pvc名字为nfs-nginx-etc,存放配置文件
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: nfs-nginx-etc
  namespace: test
  labels:
    pvc: nfs-nginx-etc
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 50Gi
  storageClassName: nfs
  selector:
    matchLabels:
      pv: nfs-pv
##部署应用nginx
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  namespace: test
  labels:
    name: nginx-test
spec:
  replicas: 2
  selector:
    matchLabels:
      name: nginx-test
  template:
    metadata:
      labels:
       name: nginx-test
    spec:
      containers:
      - name: nginx-test
        image: docker.io/nginx
        volumeMounts:
        - mountPath: /usr/share/nginx/html
          name: nginx-data
        - mountPath: /etc/nginx
          name: nginx-etc
        ports:
        - containerPort: 80
      volumes:
      - name: nginx-data
        persistentVolumeClaim:
          claimName: nfs-nginx-data
      - name: nginx-etc
        persistentVolumeClaim:
         claimName: nfs-nginx-etc
##创建service
---
apiVersion: v1
kind: Service
metadata:
  namespace: test
  name: nginx-test
  labels:
    name: nginx-test
spec:
  type: NodePort
  ports:
  - port: 80
    protocol: TCP
    targetPort: 80
    name: http
    nodePort: 30080
  selector:
    name: nginx-test
EOF

##创建资源
kubectl apply -f nfs-static-nginx-dp-many.yaml -n test

##查看pv资源
kubectl get pv -n test --show-labels

##查看pvc资源
kubectl get pvc -n test --show-labels

##查看pod
$ kubectl get pods -n test
NAME                                READY   STATUS    RESTARTS   AGE
nginx-deployment-64d6f78cdf-8bw8t   1/1     Running   0          55s
nginx-deployment-64d6f78cdf-n5n4q   1/1     Running   0          55s

#可以看到，nginx应用已经部署成功。
#nginx应用的数据目录是使用的nfs共享存储，我们在nfs共享的目录里加入index.html文件，然后再访问nginx-service暴露的端口
#切换到到nfs-server服务器上

echo "Test NFS Share discovery with nfs-static-nginx-dp-many" > /data/nfs/nginx/index.html

#在浏览器上访问kubernetes主节点的 http://master:30080，就能访问到这个页面内容了
```

# 二、nginx使用nfs动态PV

## 2、动态nfs-dynamic-nginx.yaml

```bash

```

参考文档：

https://kubernetes.io/zh/docs/tasks/run-application/run-stateless-application-deployment/  

https://blog.51cto.com/ylw6006/2071845 在kubernetes集群中运行nginx
