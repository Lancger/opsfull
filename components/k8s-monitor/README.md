```
# 1、持久化监控数据
cat > prometheus-class.yaml <<-EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast
provisioner: fuseim.pri/ifs # or choose another name, must match deployment's env PROVISIONER_NAME'
parameters:
  archiveOnDelete: "true"
EOF

#部署class.yaml
kubectl apply -f prometheus-class.yaml

#查看创建的storageclass
kubectl get sc

#2、修改 Prometheus 持久化
prometheus是一种 StatefulSet 有状态集的部署模式，所以直接将 StorageClass 配置到里面，在下面的yaml中最下面添加持久化配置
#cat prometheus/prometheus-prometheus.yaml
apiVersion: monitoring.coreos.com/v1
kind: Prometheus
metadata:
  labels:
    prometheus: k8s
  name: k8s
  namespace: monitoring
spec:
  alerting:
    alertmanagers:
    - name: alertmanager-main
      namespace: monitoring
      port: web
  baseImage: quay.io/prometheus/prometheus
  nodeSelector:
    kubernetes.io/os: linux
  podMonitorSelector: {}
  replicas: 2
  resources:
    requests:
      memory: 400Mi
  ruleSelector:
    matchLabels:
      prometheus: k8s
      role: alert-rules
  securityContext:
    fsGroup: 2000
    runAsNonRoot: true
    runAsUser: 1000
  serviceAccountName: prometheus-k8s
  serviceMonitorNamespaceSelector: {}
  serviceMonitorSelector: {}
  version: v2.11.0
  storage:                     #----添加持久化配置，指定StorageClass为上面创建的fast
    volumeClaimTemplate:
      spec:
        storageClassName: fast #---指定为fast
        resources:
          requests:
            storage: 300Gi
            
kubectl apply -f prometheus/prometheus-prometheus.yaml

#3、修改 Grafana 持久化配置

由于 Grafana 是部署模式为 Deployment，所以我们提前为其创建一个 grafana-pvc.yaml 文件，加入下面 PVC 配置。
#vim grafana-pvc.yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: grafana
  namespace: monitoring  #---指定namespace为monitoring
spec:
  storageClassName: fast #---指定StorageClass为上面创建的fast
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 200Gi

kubectl apply -f grafana-pvc.yaml

#vim grafana/grafana-deployment.yaml
......
      volumes:
      - name: grafana-storage       #-------新增持久化配置
        persistentVolumeClaim:
          claimName: grafana        #-------设置为创建的PVC名称
      #- emptyDir: {}               #-------注释掉旧的配置
      #  name: grafana-storage
      - name: grafana-datasources
        secret:
          secretName: grafana-datasources
      - configMap:
          name: grafana-dashboards
        name: grafana-dashboards
......

kubectl apply -f grafana/grafana-deployment.yaml
```
参考资料：

https://www.cnblogs.com/skyflask/articles/11410063.html  kubernetes监控方案--cAdvisor+Heapster+InfluxDB+Grafana

https://www.cnblogs.com/skyflask/p/11480988.html  kubernetes监控终极方案-kube-promethues

http://www.mydlq.club/article/10/#wow1  Kube-promethues监控k8s集群

https://jicki.me/docker/kubernetes/2019/07/22/kube-prometheus/   Coreos kube-prometheus 监控
