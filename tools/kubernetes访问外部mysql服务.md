`
k8s访问集群外独立的服务最好的方式是采用Endpoint方式(可以看作是将k8s集群之外的服务抽象为内部服务)，以mysql服务为例
`

# 一、创建endpoints
```
#创建 mysql-endpoints.yaml
cat > mysql-endpoints.yaml <<\EOF
kind: Endpoints
apiVersion: v1
metadata:
  name: mysql-production
  namespace: default
subsets:
  - addresses:
      - ip: 10.198.1.155
    ports:
      - port: 3306
EOF
```

# 二、创建service
```
#创建 mysql-service.yaml
cat > mysql-service.yaml <<\EOF
apiVersion: v1
kind: Service
metadata:
  name: mysql-production
spec:
  ports:
    - port: 3306
EOF
```
参考资料：

https://blog.csdn.net/hxpjava1/article/details/80040407   使用kubernetes访问外部服务mysql/redis
