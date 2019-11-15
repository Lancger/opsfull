Table of Contents
=================

   * [一、创建endpoints](#一创建endpoints)
   * [二、创建service](#二创建service)
   * [三、安装centos7基础镜像](#三安装centos7基础镜像)
   * [四、测试数据库连接](#四测试数据库连接)
   
`k8s访问集群外独立的服务最好的方式是采用Endpoint方式(可以看作是将k8s集群之外的服务抽象为内部服务)，以mysql服务为例`

# 一、创建endpoints
```bash
# 删除 mysql-endpoints
kubectl delete -f mysql-endpoints.yaml 

# 创建 mysql-endpoints.yaml
cat > mysql-endpoints.yaml <<\EOF
kind: Endpoints
apiVersion: v1
metadata:
  name: mysql-production
  namespace: mos-namespace
  labels:
    app: mysql-endpoint
subsets:
  - addresses:
      - ip: 10.198.1.155   #需要注意策略需要开通好
    ports:
      - port: 3306
        protocol: TCP
EOF

# 创建 mysql-endpoints
kubectl apply -f mysql-endpoints.yaml

# 查看 mysql-endpoints
kubectl get endpoints mysql-production -n mos-namespace

# 查看 mysql-endpoints详情
kubectl describe endpoints mysql-production -n mos-namespace
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
  selector:
    app: mysql-endpoint  #这里根据标签选择创建service
  ports:
    - port: 3306
      protocol: TCP
EOF

kubectl apply -f mysql-service.yaml

kubectl get svc mysql-production -n mos-namespace

kubectl describe svc mysql-production -n mos-namespace
```

# 三、安装centos7基础镜像
```bash
# 查看 mos-namespace 下的pod资源
kubectl get pods -n mos-namespace

# 清理命令行创建的deployment
kubectl delete deployment centos7-app -n mos-namespace

# 命令行跑一个centos7的bash基础容器
#kubectl run --rm --image=centos:7.2.1511 centos7-app -it --port=8080 --replicas=1 -n mos-namespace
kubectl run --image=centos:7.2.1511 centos7-app -it --port=8080 --replicas=1 -n mos-namespace

# 安装mysql客户端
yum install vim net-tools telnet nc -y
yum install -y mariadb.x86_64 mariadb-libs.x86_64
```

# 四、测试数据库连接

```bash
# 进入到容器
kubectl exec `kubectl get pods -n mos-namespace|grep centos7-app|awk '{print $1}'` -it /bin/bash -n mos-namespace

# 检查网络连通性
ping mysql-production

# 测试mysql服务端口是否OK
nc -zv mysql-production 3306

# 连接测试
mysql -h'mysql-production' -u'root' -p'password'
```
参考资料：

https://blog.csdn.net/hxpjava1/article/details/80040407   使用kubernetes访问外部服务mysql/redis

https://blog.csdn.net/liyingke112/article/details/76204038  

https://blog.csdn.net/ybt_c_index/article/details/80881157  istio 0.8 用ServiceEntry访问外部服务（如RDS）
