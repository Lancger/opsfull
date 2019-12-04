Table of Contents
=================

   * [一、创建namespace](#一创建namespace)
   * [二、创建一个 configmap](#二创建一个-configmap)
   * [三、创建 redis 容器](#三创建-redis-容器)
   * [四、创建redis-service服务](#四创建redis-service服务)
   * [五、验证redis实例](#五验证redis实例)
   
# 一、创建namespace
```bash
# 清理 namespace
kubectl delete -f mos-namespace.yaml

# 创建一个专用的 namespace
cat > mos-namespace.yaml <<\EOF
---
apiVersion: v1
kind: Namespace
metadata:
  name: mos-namespace
EOF

kubectl apply -f mos-namespace.yaml

# 查看 namespace
kubectl get namespace -A
```

# 二、创建一个 configmap

```bash
mkdir config && cd config

# 清理configmap
kubectl delete configmap redis-conf -n mos-namespace

# 创建redis配置文件
cat >redis.conf <<\EOF
#daemonize yes
pidfile /data/redis.pid
port 6379
tcp-backlog 30000
timeout 0
tcp-keepalive 10
loglevel notice
logfile /data/redis.log
databases 16
#save 900 1
#save 300 10
#save 60 10000
stop-writes-on-bgsave-error no
rdbcompression yes
rdbchecksum yes
dbfilename dump.rdb
dir /data
slave-serve-stale-data yes
slave-read-only yes
repl-diskless-sync no
repl-diskless-sync-delay 5
repl-disable-tcp-nodelay no
slave-priority 100
requirepass redispassword
maxclients 30000
appendonly no
appendfilename "appendonly.aof"
appendfsync everysec
no-appendfsync-on-rewrite no
auto-aof-rewrite-percentage 100
auto-aof-rewrite-min-size 64mb
aof-load-truncated yes
lua-time-limit 5000
slowlog-log-slower-than 10000
slowlog-max-len 128
latency-monitor-threshold 0
notify-keyspace-events KEA
hash-max-ziplist-entries 512
hash-max-ziplist-value 64
list-max-ziplist-entries 512
list-max-ziplist-value 64
set-max-intset-entries 1000
zset-max-ziplist-entries 128
zset-max-ziplist-value 64
hll-sparse-max-bytes 3000
activerehashing yes
client-output-buffer-limit normal 0 0 0
client-output-buffer-limit slave 256mb 64mb 60
client-output-buffer-limit pubsub 32mb 8mb 60
hz 10
EOF

# 在mos-namespace中创建 configmap
kubectl create configmap redis-conf --from-file=redis.conf -n mos-namespace
```

# 三、创建 redis 容器
```bash
# 清理pod
kubectl delete -f mos_redis.yaml 

cat > mos_redis.yaml <<\EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mos-redis
  namespace: mos-namespace
spec:
  selector:
    matchLabels:
      name: mos-redis
  replicas: 1
  template:
    metadata:
     labels:
       name: mos-redis
    spec:
     containers:
     - name: mos-redis
       image: redis
       volumeMounts:
       - name: mos
         mountPath: "/usr/local/etc"
       command:
         - "redis-server"
       args:
         - "/usr/local/etc/redis/redis.conf"
     volumes:
     - name: mos
       configMap:
         name: redis-conf
         items:
           - key: redis.conf
             path: redis/redis.conf
EOF

# 创建和查看 pod
kubectl apply -f mos_redis.yaml 
kubectl get pods -n mos-namespace

# 注意：configMap 会挂在 /usr/local/etc/redis/redis.conf 上。与 mountPath 和 configMap 下的 path 一同指定
```

# 四、创建redis-service服务

```bash
# 删除service
kubectl delete -f redis-service.yaml -n mos-namespace

# 编写redis-service.yaml
cat >redis-service.yaml<<\EOF
apiVersion: v1
kind: Service
metadata:
  name: redis-production
  namespace: mos-namespace
spec:
  selector:
    name: mos-redis
  ports:
    - port: 6379
      protocol: TCP
EOF

# 创建service
kubectl apply -f redis-service.yaml -n mos-namespace

# 查看service
kubectl get svc redis-production -n mos-namespace

# 查看service详情
kubectl describe svc redis-production -n mos-namespace
```


# 五、验证redis实例

1、普通方式验证

```bash
# 进入到容器
kubectl exec -it `kubectl get pods -n mos-namespace|grep redis|awk '{print $1}'` /bin/bash -n mos-namespace

redis-cli -h 127.0.0.1 -a redispassword
# 127.0.0.1:6379> set a b
# 127.0.0.1:6379> get a
"b"

# 查看日志(因为配置文件中有配置日志写到容器里的/data/redis.log文件)
kubectl exec -it `kubectl get pods -n mos-namespace|grep redis|awk '{print $1}'` /bin/bash -n mos-namespace

$ tail -100f /data/redis.log 
1:C 14 Nov 2019 06:46:13.476 # oO0OoO0OoO0Oo Redis is starting oO0OoO0OoO0Oo
1:C 14 Nov 2019 06:46:13.476 # Redis version=5.0.6, bits=64, commit=00000000, modified=0, pid=1, just started
1:C 14 Nov 2019 06:46:13.476 # Configuration loaded
1:M 14 Nov 2019 06:46:13.478 * Running mode=standalone, port=6379.
1:M 14 Nov 2019 06:46:13.478 # WARNING: The TCP backlog setting of 30000 cannot be enforced because /proc/sys/net/core/somaxconn is set to the lower value of 128.
1:M 14 Nov 2019 06:46:13.478 # Server initialized
1:M 14 Nov 2019 06:46:13.478 # WARNING you have Transparent Huge Pages (THP) support enabled in your kernel. This will create latency and memory usage issues with Redis. To fix this issue run the command 'echo never > /sys/kernel/mm/transparent_hugepage/enabled' as root, and add it to your /etc/rc.local in order to retain the setting after a reboot. Redis must be restarted after THP is disabled.
1:M 14 Nov 2019 06:46:13.478 * Ready to accept connections
```

2、通过暴露的service验证

```bash
# 命令行跑一个centos7的bash基础容器
kubectl run --image=centos:7.2.1511 centos7-app -it --port=8080 --replicas=1 -n mos-namespace

# 通过service方式验证
kubectl exec `kubectl get pods -n mos-namespace|grep centos7-app|awk '{print $1}'` -it /bin/bash -n mos-namespace

yum install -y epel-release
yum install -y redis

redis-cli -h redis-production -a redispassword
```

参考文档：

https://www.cnblogs.com/klvchen/p/10862607.html 
