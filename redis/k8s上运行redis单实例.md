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
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: mos-redis
  namespace: mos-namespace
spec:
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

# 四、验证redis实例

```bash
kubectl exec -it `kubectl get pods -n mos-namespace|grep redis|awk '{print $1}'` /bin/bash -n mos-namespace

# redis-cli -a redispassword
# 127.0.0.1:6379> set a b
# 127.0.0.1:6379> get a
"b"

#查看日志
kubectl logs -f `kubectl get pods -n mos-namespace|grep redis|awk '{print $1}'` -n mos-namespace
```
参考文档：

https://www.cnblogs.com/klvchen/p/10862607.html 
