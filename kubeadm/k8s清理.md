```
rm -rf /etc/kubernetes/
rm -rf /root/.kube/
rm -rf /var/lib/etcd/

docker rmi -f $(docker images -q)
docker rm -f `docker ps -a -q`
```
