# 同步工具

1、同步主机host文件
```
[root@master01 ~]# ./ssh_copy.sh /etc/hosts /etc/hosts
spawn scp /etc/hosts root@master01:/etc/hosts
hosts                                                                                                                                              100%  440   940.4KB/s   00:00    
spawn scp /etc/hosts root@master02:/etc/hosts
hosts                                                                                                                                              100%  440   774.6KB/s   00:00    
spawn scp /etc/hosts root@master03:/etc/hosts
hosts                                                                                                                                              100%  440     1.4MB/s   00:00    
spawn scp /etc/hosts root@slave01:/etc/hosts
hosts                                                                                                                                              100%  440   912.6KB/s   00:00    
spawn scp /etc/hosts root@slave02:/etc/hosts
hosts                                                                                                                                              100%  440   826.8KB/s   00:00    
spawn scp /etc/hosts root@slave03:/etc/hosts
hosts 
```

2、iptables多端口
```
-A RH-Firewall-1-INPUT -s 13.138.33.20/32 -p tcp -m tcp -m multiport --dports 80,443 -j ACCEPT
```
