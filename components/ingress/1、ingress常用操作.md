```
[root@master ingress]# kubectl get ingress -A
NAMESPACE     NAME                   HOSTS                 ADDRESS   PORTS   AGE
default       nginx-ingress          k8s.nginx.com                   80      40m
kube-system   kubernetes-dashboard   dashboard.test.com              80      2d21h
kube-system   traefik-web-ui         traefik-ui.test.com             80      2d21h



[root@master ingress]# kubectl delete ingress hello-tls-ingress
ingress.extensions "hello-tls-ingress" deleted
```
