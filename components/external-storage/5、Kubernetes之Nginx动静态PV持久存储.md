# 一、nginx使用nfs静态PV

## 1、静态nfs-static-nginx.yaml

```bash
kubectl delete -f nfs-static-nginx.yaml

cat >nfs-static-nginx.yaml<<\EOF
##创建namespaces
---
apiVersion: v1
kind: Namespace
metadata:
   name: test
   labels:
     name: test
##创建nfs-PV
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs-pv
  namespace: test
  labels:
    pv: nfs-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  nfs:
    path: /data/nfs/nginx/
    server: 10.198.1.155
##创建 NFS-pvc
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: nfs-pvc
  namespace: test
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 10Gi
  selector:
    matchLabels:
      pv: nfs-pv
## 部署应用Nginx
---
apiVersion: v1
kind: ReplicationController
metadata:
  name: nginx-test
  labels:
    name: nginx-test
  namespace: test
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
##创建Service
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-test
  labels:
   name: nginx-test
  namespace: test
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

kubectl apply -f nfs-static-nginx.yaml
```

# 二、nginx使用nfs动态PV

## 2、动态nfs-dynamic-nginx.yaml

```bash

```
