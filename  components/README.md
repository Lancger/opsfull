# 一、ingress介绍

K8s集群对外暴露服务的方式目前只有三种：loadblancer、nodeport、ingress。前两种熟悉起来比较快，而且使用起来也比较方便，在此就不进行介绍了。

Ingress其实就是从 kuberenets 集群外部访问集群的一个入口，将外部的请求转发到集群内不同的 Service 上，其实就相当于 nginx、haproxy 等负载均衡代理服务器，有的同学可能觉得我们直接使用 nginx 就实现了，但是只使用 nginx 这种方式有很大缺陷，每次有新服务加入的时候怎么改 Nginx 配置？不可能让我们去手动更改或者滚动更新前端的 Nginx Pod 吧？那我们再加上一个服务发现的工具比如 consul 如何？貌似是可以，对吧？而且在之前单独使用 docker 的时候，这种方式已经使用得很普遍了，Ingress 实际上就是这样实现的，只是服务发现的功能自己实现了，不需要使用第三方的服务了，然后再加上一个域名规则定义，路由信息的刷新需要一个靠 Ingress controller 来提供。

其中ingress controller目前主要有两种：基于nginx服务的ingress controller和基于traefik的ingress controller。

而其中traefik的ingress controller，目前支持http和https协议

# 二、ingress的工作原理

## ingress由两部分组成：ingress controller和ingress服务。

Ingress controller 可以理解为一个监听器，通过不断地与 kube-apiserver 打交道，实时的感知后端 service、pod 的变化，当得到这些变化信息后，Ingress controller 再结合 Ingress 的配置，更新反向代理负载均衡器，达到服务发现的作用。其实这点和服务发现工具 consul consul-template 非常类似。

## ingress具体的工作原理如下:

ingress contronler通过与k8s的api进行交互，动态的去感知k8s集群中ingress服务规则的变化，然后读取它，并按照定义的ingress规则，转发到k8s集群中对应的service。

而这个ingress规则写明了哪个域名对应k8s集群中的哪个service，然后再根据ingress-controller中的nginx配置模板，生成一段对应的nginx配置。

然后再把该配置动态的写到ingress-controller的pod里，该ingress-controller的pod里面运行着一个nginx服务，控制器会把生成的nginx配置写入到nginx的配置文件中，然后reload一下，使其配置生效。以此来达到域名分配置及动态更新的效果。

# 三、Traefik

Traefik 是一款开源的反向代理与负载均衡工具。它最大的优点是能够与常见的微服务系统直接整合，可以实现自动化动态配置。目前支持 Docker、Swarm、Mesos/Marathon、 Mesos、Kubernetes、Consul、Etcd、Zookeeper、BoltDB、Rest API 等等后端模型。

要使用 traefik，我们同样需要部署 traefik 的 Pod，由于我们演示的集群中只有 master 节点有外网网卡，所以我们这里只有 master 这一个边缘节点，我们将 traefik 部署到该节点上即可。

  ![traefik原理图](https://github.com/Lancger/opsfull/blob/master/images/traefik-architecture.png)

首先，为安全起见我们这里使用 RBAC 安全认证方式：(rbac.yaml)：
```
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: traefik-ingress-controller
  namespace: kube-system
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: traefik-ingress-controller
rules:
  - apiGroups:
      - ""
    resources:
      - services
      - endpoints
      - secrets
    verbs:
      - get
      - list
      - watch
  - apiGroups:
      - extensions
    resources:
      - ingresses
    verbs:
      - get
      - list
      - watch
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: traefik-ingress-controller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: traefik-ingress-controller
subjects:
- kind: ServiceAccount
  name: traefik-ingress-controller
  namespace: kube-system
```