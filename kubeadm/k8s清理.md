```
rm -rf /etc/kube
rm -rf /root/.kube/
rm -rf /var/lib/etcd

docker rmi -f $(docker images -q)
docker rm -f `docker ps -a -q`
```
