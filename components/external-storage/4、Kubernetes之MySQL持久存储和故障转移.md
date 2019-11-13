# 一、MySQL持久化演练

## 1、数据库提供持久化存储，主要分为下面几个步骤：

    1、创建 PV 和 PVC

    2、部署 MySQL

    3、向 MySQL 添加数据

    4、模拟节点宕机故障，Kubernetes 将 MySQL 自动迁移到其他节点

    5、验证数据一致性
   

# 二、静态PV PVC

```bash
PV就好比是一个仓库，我们需要先购买一个仓库，即定义一个PV存储服务，例如CEPH,NFS,Local Hostpath等等。

PVC就好比租户，pv和pvc是一对一绑定的，挂载到POD中，一个pvc可以被多个pod挂载。
```

## 1、创建 PV

```bash
# 清理pv资源
kubectl delete -f mysql-static-pv.yaml

# 编写pv yaml资源文件
cat > mysql-static-pv.yaml <<\EOF
apiVersion: v1
kind: PersistentVolume
metadata:
  name: mysql-static-pv
spec:
  capacity:
    storage: 80Gi

  accessModes:
    - ReadWriteOnce
  #ReadWriteOnce - 卷可以由单个节点以读写方式挂载
  #ReadOnlyMany  - 卷可以由许多节点以只读方式挂载
  #ReadWriteMany - 卷可以由许多节点以读写方式挂载

  persistentVolumeReclaimPolicy: Retain
  #Retain，不清理, 保留 Volume（需要手动清理）
  #Recycle，删除数据，即 rm -rf /thevolume/*（只有 NFS 和 HostPath 支持）
  #Delete，删除存储资源，比如删除 AWS EBS 卷（只有 AWS EBS, GCE PD, Azure Disk 和 Cinder 支持）

  nfs:
    path: /data/nfs/
    server: 10.198.1.156
  mountOptions:
    - vers=4
    - minorversion=0
    - noresvport
EOF

# 部署pv到集群中
kubectl apply -f mysql-static-pv.yaml

# 查看pv
$ kubectl get pv
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM                                           STORAGECLASS          REASON   AGE
mysql-static-pv                            80Gi       RWO            Retain           Available                                                                                  4m20s
```

## 2、创建PVC

```bash
# 清理pvc资源
kubectl delete -f mysql-pvc.yaml 

# 编写pvc yaml资源文件
cat > mysql-pvc.yaml <<\EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mysql-static-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 80Gi
EOF

# 创建pvc资源
kubectl apply -f mysql-pvc.yaml

# 查看pvc
$ kubectl get pvc
NAME               STATUS        VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
mysql-static-pvc   Bound         pvc-c55f8695-2a0b-4127-a60b-5c1aba8b9104   80Gi       RWO            nfs-storage    81s
```

# 三、部署 MySQL

## 1、MySQL 的配置文件mysql.yaml如下：

```bash
kubectl delete -f mysql.yaml

cat >mysql.yaml<<\EOF
apiVersion: v1
kind: Service
metadata:
  name: mysql
spec:
  ports:
  - port: 3306
  selector:
    app: mysql
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: mysql
spec:
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:5.6
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: password
        ports:
        - name: mysql
          containerPort: 3306
        volumeMounts:
        - name: mysql-persistent-storage
          mountPath: /var/lib/mysql
      volumes:
      - name: mysql-persistent-storage
        persistentVolumeClaim:
          claimName: mysql-static-pvc
EOF

kubectl apply -f mysql.yaml

# PVC mysql-static-pvc Bound 的 PV mysql-static-pv 将被 mount 到 MySQL 的数据目录 /var/lib/mysql。
```

## 2、更新 MySQL 数据

MySQL 被部署到 k8s-node02，下面通过客户端访问 Service mysql：

```bash
$ kubectl run -it --rm --image=mysql:5.6 --restart=Never mysql-client -- mysql -h mysql -ppassword
If you don't see a command prompt, try pressing enter.
mysql>

我们在mysql库中创建一个表myid，然后在表里新增几条数据。

mysql> use mysql
Database changed

mysql> drop table myid;
Query OK, 0 rows affected (0.12 sec)

mysql> create table myid(id int(4));
Query OK, 0 rows affected (0.23 sec)

mysql> insert myid values(888);
Query OK, 1 row affected (0.03 sec)

mysql> select * from myid;
+------+
| id   |
+------+
|  888 |
+------+
1 row in set (0.00 sec)
```

## 3、故障转移

我们现在把 node02 机器关机，模拟节点宕机故障。


```bash
1、一段时间之后，Kubernetes 将 MySQL 迁移到 k8s-node01

$ kubectl get pod -o wide
NAME                     READY   STATUS        RESTARTS   AGE   IP            NODE     NOMINATED NODE   READINESS GATES
mysql-7686899cf9-8z6tc   1/1     Running       0          21s   10.244.1.19   node01   <none>           <none>
mysql-7686899cf9-d4m42   1/1     Terminating   0          23m   10.244.2.17   node02   <none>           <none>

2、验证数据的一致性

$ kubectl run -it --rm --image=mysql:5.6 --restart=Never mysql-client -- mysql -h mysql -ppassword
If you don't see a command prompt, try pressing enter.
mysql> use mysql
Reading table information for completion of table and column names
You can turn off this feature to get a quicker startup with -A

Database changed
mysql> select * from myid;
+------+
| id   |
+------+
|  888 |
+------+
1 row in set (0.00 sec)

3、MySQL 服务恢复，数据也完好无损，我们可以可以在存储节点上面查看一下生成的数据库文件。

[root@nfs_server mysql-pv]# ll
-rw-rw---- 1 systemd-bus-proxy ssh_keys       56 12月 14 09:53 auto.cnf
-rw-rw---- 1 systemd-bus-proxy ssh_keys 12582912 12月 14 10:15 ibdata1
-rw-rw---- 1 systemd-bus-proxy ssh_keys 50331648 12月 14 10:15 ib_logfile0
-rw-rw---- 1 systemd-bus-proxy ssh_keys 50331648 12月 14 09:53 ib_logfile1
drwx------ 2 systemd-bus-proxy ssh_keys     4096 12月 14 10:05 mysql
drwx------ 2 systemd-bus-proxy ssh_keys     4096 12月 14 09:53 performance_schema
```

# 四、全新命名空间使用

```bash
kubectl create ns test-ns

kubectl apply -f mysql-pvc.yaml -n test-ns

kubectl apply -f mysql.yaml -n test-ns
```

参考文档：

https://blog.51cto.com/wzlinux/2330295   Kubernetes 之 MySQL 持久存储和故障转移(十一)

https://qingmu.io/2019/08/11/Run-mysql-on-kubernetes/ 从部署mysql聊一聊有状态服务和PV及PVC
