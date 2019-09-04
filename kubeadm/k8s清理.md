```
rm -rf /etc/kubernetes/
rm -rf /root/.kube/
rm -rf /var/lib/etcd/
rm -rf /var/lib/kubelet/

docker rmi -f $(docker images -q)
docker rm -f `docker ps -a -q`
```
