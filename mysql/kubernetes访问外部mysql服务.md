`
k8s访问集群外独立的服务最好的方式是采用Endpoint方式(可以看作是将k8s集群之外的服务抽象为内部服务)，以mysql服务为例
`

# 一、创建endpoints
```bash
kubectl delete -f mysql-endpoints.yaml 

#创建 mysql-endpoints.yaml
cat > mysql-endpoints.yaml <<\EOF
kind: Endpoints
apiVersion: v1
metadata:
  name: mysql-production
  namespace: mos-namespace
subsets:
  - addresses:
      - ip: 10.198.1.155
    ports:
      - port: 3306
EOF

kubectl apply -f mysql-endpoints.yaml

kubectl describe endpoints -n mos-namespace
```

# 二、创建service
```bash
kubectl delete -f mysql-service.yaml

#创建 mysql-service.yaml
cat > mysql-service.yaml <<\EOF
apiVersion: v1
kind: Service
metadata:
  name: mysql-production
  namespace: mos-namespace
spec:
  ports:
    - port: 3306
EOF

kubectl apply -f mysql-service.yaml

kubectl describe svc mysql-production -n mos-namespace
```

# 三、测试连接数据库
```bash
# 查看 mos-namespace 下的pod资源
kubectl get pods -n mos-namespace

# 清理命令行创建的deployment
kubectl delete deployment centos7-app -n mos-namespace

# 命令行跑一个centos7的bash基础容器
kubectl run --image=centos:7.2.1511 centos7-app -it --port=8080 --replicas=1 -n mos-namespace

# 进入到容器
kubectl exec `kubectl get pods -n mos-namespace|grep centos7-app|awk '{print $1}'` -it /bin/bash -n mos-namespace

# 安装mysql客户端

```
参考资料：

https://blog.csdn.net/hxpjava1/article/details/80040407   使用kubernetes访问外部服务mysql/redis
