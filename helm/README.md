# 一、Helm - K8S的包管理器

类似Centos的yum

## 1、Helm架构
```bash
helm包括chart和release.
helm包含2个组件,Helm客户端和Tiller服务器.
```

## 2、Helm客户端安装
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

#源码安装
wget -O helm-v2.16.0-linux-amd64.tar.gz https://get.helm.sh/helm-v2.16.0-linux-amd64.tar.gz
tar -zxvf helm-v2.16.0-linux-amd64.tar.gz
cd linux-amd64 #进入解压目录会看到两个可执行文件helm和tiller, 若采用容器化部署到kubernetes中，则可以不用管tiller，只需将helm复制到/usr/bin目录即可
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

```bash

```

参考文档：

https://www.cnblogs.com/hongdada/p/11284534.html  Helm 安装部署Kubernetes的dashboard

https://www.cnblogs.com/chanix/p/11731388.html  Helm - K8S的包管理器

https://www.cnblogs.com/peitianwang/p/11649621.html


