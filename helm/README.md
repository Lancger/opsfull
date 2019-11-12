# 一、Helm - K8S的包管理器

类似Centos的yum

## 1、Helm架构
```bash
helm包括chart和release.
helm包含2个组件,Helm客户端和Tiller服务器.
```

## 2、Helm客户端安装

1、脚本安装
```bash
#安装
curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get |bash

#查看
which helm

#因服务器端还没安装,这里会报无法连接
helm version 

#添加命令补全
helm completion bash > .helmrc
echo "source .helmrc" >> .bashrc
```

2、源码安装
```bash
#源码安装
#curl -O https://get.helm.sh/helm-v2.16.0-linux-amd64.tar.gz

wget -O helm-v2.16.0-linux-amd64.tar.gz https://get.helm.sh/helm-v2.16.0-linux-amd64.tar.gz
tar -zxvf helm-v2.16.0-linux-amd64.tar.gz
cd linux-amd64 #若采用容器化部署到kubernetes中，则可以不用管tiller，只需将helm复制到/usr/bin目录即可
cp helm /usr/bin/
echo "source <(helm completion bash)" >> /root/.bashrc # 命令自动补全
```

## 3、Tiller服务器端安装
```bash
helm init --upgrade -i registry.cn-hangzhou.aliyuncs.com/google_containers/tiller:v2.16.0 --stable-repo-url https://kubernetes.oss-cn-hangzhou.aliyuncs.com/charts

#查看
kubectl get --namespace=kube-system service tiller-deploy
kubectl get --namespace=kube-system deployments. tiller-deploy
kubectl get --namespace=kube-system pods|grep tiller-deploy

#能够看到服务器版本信息
helm version

#添加新的repo
helm repo add stable http://mirror.azure.cn/kubernetes/charts/
```

## 4、Helm使用
```bash
#搜索 
helm search

#执行命名添加权限
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'

#安装chart的mysql应用
helm install stable/mysql

会自动部署 Service,Deployment,Secret 和 PersistentVolumeClaim,并给与很多提示信息,比如mysql密码获取,连接端口等.

#查看release各个对象
kubectl get service doltish-beetle-mysql
kubectl get deployments. doltish-beetle-mysql
kubectl get pods doltish-beetle-mysql-75fbddbd9d-f64j4
kubectl get pvc doltish-beetle-mysql
helm list # 显示已经部署的release

#删除
helm delete doltish-beetle
kubectl get pods
kubectl get service
kubectl get deployments.
kubectl get pvc
```

# 二、Helm 安装部署Kubernetes的dashboard

## 1、创建tls secret

```bash
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout ./tls.key -out ./tls.crt -subj "/CN=k8s.test.com"
```

## 2、安装tls secret
```bash
kubectl -n kube-system  create secret tls dashboard-tls-secret --key ./tls.key --cert ./tls.crt

kubectl get secret -n kube-system |grep dashboard
```

## 3、安装

```bash
cat >kubernetes-dashboard.yaml<<\EOF
image:
  repository: k8s.gcr.io/kubernetes-dashboard-amd64
  tag: v1.10.1
ingress:
  enabled: true
  hosts: 
    - k8s.test.com
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
  tls:
    - secretName: dashboard-tls-secret
      hosts:
      - k8s.test.com
nodeSelector:
    node-role.kubernetes.io/edge: ''
tolerations:
    - key: node-role.kubernetes.io/master
      operator: Exists
      effect: NoSchedule
    - key: node-role.kubernetes.io/master
      operator: Exists
      effect: PreferNoSchedule
rbac:
  clusterAdminRole: true
EOF

相比默认配置，修改了以下配置项：

  ingress.enabled - 置为 true 开启 Ingress，用 Ingress 将 Kubernetes Dashboard 服务暴露出来，以便让我们浏览器能够访问
  
  ingress.annotations - 指定 ingress.class 为 nginx，让我们安装 Nginx Ingress Controller 来反向代理 Kubernetes Dashboard 服务；由于 Kubernetes Dashboard 后端服务是以 https 方式监听的，而 Nginx Ingress Controller 默认会以 HTTP 协议将请求转发给后端服务，用secure-backends这个 annotation 来指示 Nginx Ingress Controller 以 HTTPS 协议将请求转发给后端服务
  
  ingress.hosts - 这里替换为证书配置的域名
  
  Ingress.tls - secretName 配置为 cert-manager 生成的免费证书所在的 Secret 资源名称，hosts 替换为证书配置的域名
  
  rbac.clusterAdminRole - 置为 true 让 dashboard 的权限够大，这样我们可以方便操作多个 namespace

```

## 4、命令安装

```bash
helm install stable/kubernetes-dashboard \
-n kubernetes-dashboard \
--namespace kube-system  \
-f kubernetes-dashboard.yaml
```


参考文档：

https://www.cnblogs.com/bugutian/p/11366556.html  国内不fq安装K8S三: 使用helm安装kubernet-dashboard

https://www.cnblogs.com/hongdada/p/11284534.html  Helm 安装部署Kubernetes的dashboard

https://www.cnblogs.com/chanix/p/11731388.html  Helm - K8S的包管理器

https://www.cnblogs.com/peitianwang/p/11649621.html


