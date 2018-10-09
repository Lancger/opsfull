1.创建一个测试用的deployment
```
[root@linux-node1 ~]# kubectl run net-test --image=alpine --replicas=2 sleep 360000
```

2.查看获取IP情况
```
[root@linux-node1 ~]# kubectl get pod -o wide
NAME                        READY     STATUS    RESTARTS   AGE       IP          NODE
net-test-5767cb94df-6smfk   1/1       Running   1          1h        10.2.69.3   192.168.56.12
net-test-5767cb94df-ctkhz   1/1       Running   1          1h        10.2.17.3   192.168.56.13
```

3.测试联通性
```
[root@linux-node1 ~]# ping -c 1 10.2.69.3
PING 10.2.69.3 (10.2.69.3) 56(84) bytes of data.
64 bytes from 10.2.69.3: icmp_seq=1 ttl=61 time=1.39 ms

--- 10.2.69.3 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 1.396/1.396/1.396/0.000 ms

[root@linux-node1 ~]# ping -c 1 10.2.17.3
PING 10.2.17.3 (10.2.17.3) 56(84) bytes of data.
64 bytes from 10.2.17.3: icmp_seq=1 ttl=61 time=1.16 ms

--- 10.2.17.3 ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 1.164/1.164/1.164/0.000 ms

#如果要在master节点不能ping通pod的IP,则需要检查flanneld服务,下面是各节点的网卡ip情况(发现各节点的flannel0的ip网段都是不一样的)
#node1
[root@linux-node1 ~]# ifconfig
docker0: flags=4099<UP,BROADCAST,MULTICAST>  mtu 1500
        inet 10.2.41.1  netmask 255.255.255.0  broadcast 10.2.41.255
        ether 02:42:77:d9:95:e3  txqueuelen 0  (Ethernet)
        RX packets 0  bytes 0 (0.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 0  bytes 0 (0.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 192.168.56.11  netmask 255.255.255.0  broadcast 192.168.56.255
        ether 00:0c:29:e6:00:79  txqueuelen 1000  (Ethernet)
        RX packets 75548  bytes 10771254 (10.2 MiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 74344  bytes 12700211 (12.1 MiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

flannel0: flags=4305<UP,POINTOPOINT,RUNNING,NOARP,MULTICAST>  mtu 1472
        inet 10.2.41.0  netmask 255.255.0.0  destination 10.2.41.0
        unspec 00-00-00-00-00-00-00-00-00-00-00-00-00-00-00-00  txqueuelen 500  (UNSPEC)
        RX packets 30  bytes 2520 (2.4 KiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 30  bytes 2520 (2.4 KiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
        inet 127.0.0.1  netmask 255.0.0.0
        loop  txqueuelen 1000  (Local Loopback)
        RX packets 34140  bytes 8049438 (7.6 MiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 34140  bytes 8049438 (7.6 MiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

#node2
[root@linux-node2 ~]# ifconfig
docker0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1400
        inet 10.2.69.1  netmask 255.255.255.0  broadcast 10.2.69.255
        ether 02:42:de:56:b5:1e  txqueuelen 0  (Ethernet)
        RX packets 10  bytes 448 (448.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 9  bytes 546 (546.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 192.168.56.12  netmask 255.255.255.0  broadcast 192.168.56.255
        ether 00:0c:29:ee:65:40  txqueuelen 1000  (Ethernet)
        RX packets 32893  bytes 4996885 (4.7 MiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 32877  bytes 3737878 (3.5 MiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

flannel0: flags=4305<UP,POINTOPOINT,RUNNING,NOARP,MULTICAST>  mtu 1472
        inet 10.2.69.0  netmask 255.255.0.0  destination 10.2.69.0
        unspec 00-00-00-00-00-00-00-00-00-00-00-00-00-00-00-00  txqueuelen 500  (UNSPEC)
        RX packets 3  bytes 252 (252.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 3  bytes 252 (252.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
        inet 127.0.0.1  netmask 255.0.0.0
        loop  txqueuelen 1000  (Local Loopback)
        RX packets 347  bytes 36887 (36.0 KiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 347  bytes 36887 (36.0 KiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

veth09ea856c: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1400
        ether c6:be:00:bd:a9:18  txqueuelen 0  (Ethernet)
        RX packets 10  bytes 588 (588.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 9  bytes 546 (546.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

#node3
[root@linux-node3 ~]# ifconfig
docker0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1400
        inet 10.2.17.1  netmask 255.255.255.0  broadcast 10.2.17.255
        ether 02:42:ac:11:ac:3c  txqueuelen 0  (Ethernet)
        RX packets 32  bytes 2408 (2.3 KiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 31  bytes 2814 (2.7 KiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 192.168.56.13  netmask 255.255.255.0  broadcast 192.168.56.255
        ether 00:0c:29:53:f4:b1  txqueuelen 1000  (Ethernet)
        RX packets 47504  bytes 7138550 (6.8 MiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 48402  bytes 8310935 (7.9 MiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

flannel0: flags=4305<UP,POINTOPOINT,RUNNING,NOARP,MULTICAST>  mtu 1472
        inet 10.2.17.0  netmask 255.255.0.0  destination 10.2.17.0
        unspec 00-00-00-00-00-00-00-00-00-00-00-00-00-00-00-00  txqueuelen 500  (UNSPEC)
        RX packets 27  bytes 2268 (2.2 KiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 27  bytes 2268 (2.2 KiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
        inet 127.0.0.1  netmask 255.0.0.0
        loop  txqueuelen 1000  (Local Loopback)
        RX packets 129  bytes 13510 (13.1 KiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 129  bytes 13510 (13.1 KiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

veth8630a55b: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1400
        ether 72:e9:df:4f:f6:64  txqueuelen 0  (Ethernet)
        RX packets 32  bytes 2856 (2.7 KiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 31  bytes 2814 (2.7 KiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
```

4、创建nginx服务
```
#创建deployment文件
[root@linux-node1 ~]# vim  nginx-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  labels:
    app: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.13.12
        ports:
        - containerPort: 80

#创建deployment
[root@linux-node1 ~]# kubectl create -f nginx-deployment.yaml
deployment.apps "nginx-deployment" created


#查看deployment
[root@linux-node1 ~]# kubectl get deployment
NAME               DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
nginx-deployment   3         3         3            2           48s


#查看deployment详情
[root@linux-node1 ~]# kubectl describe deployment nginx-deployment
Name:                   nginx-deployment
Namespace:              default
CreationTimestamp:      Tue, 09 Oct 2018 15:11:33 +0800
Labels:                 app=nginx
Annotations:            deployment.kubernetes.io/revision=1
Selector:               app=nginx
Replicas:               3 desired | 3 updated | 3 total | 3 available | 0 unavailable
StrategyType:           RollingUpdate
MinReadySeconds:        0
RollingUpdateStrategy:  25% max unavailable, 25% max surge
Pod Template:
  Labels:  app=nginx
  Containers:
   nginx:
    Image:        nginx:1.13.12
    Port:         80/TCP
    Host Port:    0/TCP
    Environment:  <none>
    Mounts:       <none>
  Volumes:        <none>
Conditions:
  Type           Status  Reason
  ----           ------  ------
  Available      True    MinimumReplicasAvailable
  Progressing    True    NewReplicaSetAvailable
OldReplicaSets:  <none>
NewReplicaSet:   nginx-deployment-6c45fc49cb (3/3 replicas created)
Events:
  Type    Reason             Age   From                   Message
  ----    ------             ----  ----                   -------
  Normal  ScalingReplicaSet  2m    deployment-controller  Scaled up replica set nginx-deployment-6c45fc49cb to 3


#查看pod
[root@linux-node1 ~]# kubectl get pod -o wide
NAME                                READY     STATUS    RESTARTS   AGE       IP          NODE
nginx-deployment-6c45fc49cb-7rwdp   1/1       Running   0          4m        10.2.76.5   192.168.56.12
nginx-deployment-6c45fc49cb-8dgkd   1/1       Running   0          4m        10.2.76.4   192.168.56.12
nginx-deployment-6c45fc49cb-clgkl   1/1       Running   0          4m        10.2.76.4   192.168.56.13


#查看pod详情
[root@linux-node1 ~]# kubectl describe pod nginx-deployment-6c45fc49cb-7rwdp
Name:           nginx-deployment-6c45fc49cb-7rwdp
Namespace:      default
Node:           192.168.56.12/192.168.56.12
Start Time:     Tue, 09 Oct 2018 15:11:33 +0800
Labels:         app=nginx
                pod-template-hash=2701970576
Annotations:    <none>
Status:         Running
IP:             10.2.76.5
Controlled By:  ReplicaSet/nginx-deployment-6c45fc49cb
Containers:
  nginx:
    Container ID:   docker://0ab9b4f9bf3691f16e9cb6836a7375cb7f886398bfa8a81147e9a24f3634d591
    Image:          nginx:1.13.12
    Image ID:       docker-pullable://nginx@sha256:b1d09e9718890e6ebbbd2bc319ef1611559e30ce1b6f56b2e3b479d9da51dc35
    Port:           80/TCP
    Host Port:      0/TCP
    State:          Running
      Started:      Tue, 09 Oct 2018 15:12:33 +0800
    Ready:          True
    Restart Count:  0
    Environment:    <none>
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from default-token-4cgj8 (ro)
Conditions:
  Type           Status
  Initialized    True
  Ready          True
  PodScheduled   True
Volumes:
  default-token-4cgj8:
    Type:        Secret (a volume populated by a Secret)
    SecretName:  default-token-4cgj8
    Optional:    false
QoS Class:       BestEffort
Node-Selectors:  <none>
Tolerations:     <none>
Events:
  Type    Reason                 Age   From                    Message
  ----    ------                 ----  ----                    -------
  Normal  Scheduled              4m    default-scheduler       Successfully assigned nginx-deployment-6c45fc49cb-7rwdp to 192.168.56.12
  Normal  SuccessfulMountVolume  4m    kubelet, 192.168.56.12  MountVolume.SetUp succeeded for volume "default-token-4cgj8"
  Normal  Pulling                4m    kubelet, 192.168.56.12  pulling image "nginx:1.13.12"
  Normal  Pulled                 3m    kubelet, 192.168.56.12  Successfully pulled image "nginx:1.13.12"
  Normal  Created                3m    kubelet, 192.168.56.12  Created container
  Normal  Started                3m    kubelet, 192.168.56.12  Started container


#测试pod访问
测试访问nginx镜像（在对应的节点上测试，本来是其他节点也可以正常访问的）
[root@linux-node3 ~]# curl --head http://10.2.76.4
HTTP/1.1 200 OK
Server: nginx/1.13.12
Date: Tue, 09 Oct 2018 07:17:55 GMT
Content-Type: text/html
Content-Length: 612
Last-Modified: Mon, 09 Apr 2018 16:01:09 GMT
Connection: keep-alive
ETag: "5acb8e45-264"
Accept-Ranges: bytes

```

5、更新Deployment
```
#--record  记录日志，方便以后回滚
[root@linux-node1 ~]# kubectl set image deployment/nginx-deployment nginx=nginx:1.12.1 --record
deployment.apps "nginx-deployment" image updated

```

6、查看更新后的Deployment
```
#这里发现镜像已经更新为1.12.1版本了，然后CURRENT（当前镜像数为4个，期望值DESIRED为3个，说明正在进行滚动更新）
[root@linux-node1 ~]# kubectl get deployment -o wide
NAME               DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE       CONTAINERS   IMAGES         SELECTOR
nginx-deployment   3         4         1            3           13m       nginx        nginx:1.12.1   app=nginx
```

7、查看历史记录
```
[root@linux-node1 ~]# kubectl rollout history deployment/nginx-deployment
deployments "nginx-deployment"
REVISION  CHANGE-CAUSE
1         <none>               ---第一个没有，是因为我们创建的时候没有加上--record参数
4         kubectl set image deployment/nginx-deployment nginx=nginx:1.12.2 --record=true
5         kubectl set image deployment/nginx-deployment nginx=nginx:1.12.1 --record=true
```

7、查看具体某一个版本的升级历史
```
[root@linux-node1 ~]# kubectl rollout history deployment/nginx-deployment --revision=1
deployments "nginx-deployment" with revision #1
Pod Template:
  Labels:	app=nginx
	pod-template-hash=2701970576
  Containers:
   nginx:
    Image:	nginx:1.13.12
    Port:	80/TCP
    Host Port:	0/TCP
    Environment:	<none>
    Mounts:	<none>
  Volumes:	<none>
```

8、快速回滚到上一个版本
```
[root@linux-node1 ~]# kubectl rollout undo deployment/nginx-deployment
deployment.apps "nginx-deployment"
[root@linux-node1 ~]#
```

9、扩容到5个节点
```
[root@linux-node1 ~]# kubectl get pod -o wide   ----之前是3个pod
NAME                                READY     STATUS    RESTARTS   AGE       IP           NODE
nginx-deployment-7498dc98f8-48lqg   1/1       Running   0          2m        10.2.76.15   192.168.56.12
nginx-deployment-7498dc98f8-g4zkp   1/1       Running   0          2m        10.2.76.9    192.168.56.13
nginx-deployment-7498dc98f8-z2466   1/1       Running   0          2m        10.2.76.16   192.168.56.12

[root@linux-node1 ~]# kubectl scale deployment nginx-deployment --replicas 5
deployment.extensions "nginx-deployment" scaled

[root@linux-node1 ~]# kubectl get pod -o wide     ----现在扩容到了5个pod
NAME                                READY     STATUS    RESTARTS   AGE       IP           NODE
nginx-deployment-7498dc98f8-28894   1/1       Running   0          8s        10.2.76.10   192.168.56.13
nginx-deployment-7498dc98f8-48lqg   1/1       Running   0          2m        10.2.76.15   192.168.56.12
nginx-deployment-7498dc98f8-g4zkp   1/1       Running   0          2m        10.2.76.9    192.168.56.13
nginx-deployment-7498dc98f8-tt7z5   1/1       Running   0          7s        10.2.76.17   192.168.56.12
nginx-deployment-7498dc98f8-z2466   1/1       Running   0          2m        10.2.76.16   192.168.56.12
```

10、Pod ip 变化频繁, 引入service-ip
```
#创建nginx-server
[root@linux-node1 ~]# cat nginx-service.yaml
kind: Service
apiVersion: v1
metadata:
  name: nginx-service
spec:
  selector:
    app: nginx
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
    
    
[root@linux-node1 ~]# kubectl create -f nginx-service.yaml
service "nginx-service" created

#发现给我们创建了一个vip 10.1.46.200 并且通过lvs做了负载均衡
[root@linux-node1 ~]# kubectl get service
NAME            TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)   AGE
kubernetes      ClusterIP   10.1.0.1      <none>        443/TCP   3h
nginx-service   ClusterIP   10.1.46.200   <none>        80/TCP    5m

#在node节点使用ipvsadm -Ln查看负载均衡后端节点
[root@linux-node2 ~]# ipvsadm -Ln
IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  10.1.46.200:80 rr
  -> 10.2.76.11:80                Masq    1      0          0
  -> 10.2.76.12:80                Masq    1      0          0
  -> 10.2.76.13:80                Masq    1      0          0
  -> 10.2.76.18:80                Masq    1      0          0
  -> 10.2.76.19:80                Masq    1      0          0
  
#在master上访问vip不行，是因为没有安装kube-proxy服务，需要在node节点去测试验证
[root@linux-node1 ~]# curl --head http://10.1.46.200

[root@linux-node2 ~]# curl --head http://10.1.46.200
HTTP/1.1 200 OK
Server: nginx/1.10.3
Date: Tue, 09 Oct 2018 07:55:57 GMT
Content-Type: text/html
Content-Length: 612
Last-Modified: Tue, 31 Jan 2017 15:01:11 GMT
Connection: keep-alive
ETag: "5890a6b7-264"
Accept-Ranges: bytes

#每执行一次curl --head http://10.1.46.200请求，后端InActConn连接数就会增加1
[root@linux-node2 ~]# ipvsadm -Ln
IP Virtual Server version 1.2.1 (size=4096)
Prot LocalAddress:Port Scheduler Flags
  -> RemoteAddress:Port           Forward Weight ActiveConn InActConn
TCP  10.1.46.200:80 rr
  -> 10.2.76.11:80                Masq    1      0          1
  -> 10.2.76.12:80                Masq    1      0          1
  -> 10.2.76.13:80                Masq    1      0          2
  -> 10.2.76.18:80                Masq    1      0          2
  -> 10.2.76.19:80                Masq    1      0          2
```
