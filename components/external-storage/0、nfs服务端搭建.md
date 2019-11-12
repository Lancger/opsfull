## 一、nfs服务端
```bash
#所有节点安装nfs
yum install -y nfs-utils rpcbind

#创建nfs目录
mkdir -p /nfs/data/

#修改权限
chmod -R 666 /nfs/data

#编辑export文件
vim /etc/exports
/nfs/data 192.168.56.0/24(rw,async,no_root_squash)
#如果设置为 /nfs/data *(rw,async,no_root_squash) 则对所以的IP都有效

常用选项：
   ro：客户端挂载后，其权限为只读，默认选项；
   rw:读写权限；
   sync：同时将数据写入到内存与硬盘中；
   async：异步，优先将数据保存到内存，然后再写入硬盘；
   Secure：要求请求源的端口小于1024
用户映射：
   root_squash:当NFS客户端使用root用户访问时，映射到NFS服务器的匿名用户；
   no_root_squash:当NFS客户端使用root用户访问时，映射到NFS服务器的root用户；
   all_squash:全部用户都映射为服务器端的匿名用户；
   anonuid=UID：将客户端登录用户映射为此处指定的用户uid；
   anongid=GID：将客户端登录用户映射为此处指定的用户gid

#配置生效
exportfs -r

#查看生效
exportfs

#启动rpcbind、nfs服务
systemctl restart rpcbind && systemctl enable rpcbind
systemctl restart nfs && systemctl enable nfs

#查看 RPC 服务的注册状况  (注意/etc/hosts.deny 里面需要放开以下服务)
$ rpcinfo -p localhost      
   program vers proto   port  service
    100000    4   tcp    111  portmapper
    100000    3   tcp    111  portmapper
    100000    2   tcp    111  portmapper
    100000    4   udp    111  portmapper
    100000    3   udp    111  portmapper
    100000    2   udp    111  portmapper
    100005    1   udp  20048  mountd
    100005    1   tcp  20048  mountd
    100005    2   udp  20048  mountd
    100005    2   tcp  20048  mountd
    100005    3   udp  20048  mountd
    100005    3   tcp  20048  mountd
    100024    1   udp  34666  status
    100024    1   tcp   7951  status
    100003    3   tcp   2049  nfs
    100003    4   tcp   2049  nfs
    100227    3   tcp   2049  nfs_acl
    100003    3   udp   2049  nfs
    100003    4   udp   2049  nfs
    100227    3   udp   2049  nfs_acl
    100021    1   udp  31088  nlockmgr
    100021    3   udp  31088  nlockmgr
    100021    4   udp  31088  nlockmgr
    100021    1   tcp  27131  nlockmgr
    100021    3   tcp  27131  nlockmgr
    100021    4   tcp  27131  nlockmgr

#修改/etc/hosts.allow放开rpcbind(nfs服务端和客户端都要加上)
chattr -i /etc/hosts.allow
echo "nfsd:all" >>/etc/hosts.allow
echo "rpcbind:all" >>/etc/hosts.allow
echo "mountd:all" >>/etc/hosts.allow
chattr +i /etc/hosts.allow

#showmount测试
showmount -e 192.168.56.11

#tcpdmatch测试
$ tcpdmatch rpcbind 192.168.56.11
client:   address  192.168.56.11
server:   process  rpcbind
access:   granted
```

## 二、nfs客户端
```bash
yum install -y nfs-utils rpcbind

#客户端创建目录，然后执行挂载
mkdir -p /mnt/nfs   #(注意挂载成功后，/mnt下原有数据将会被隐藏，无法找到)

mount -t nfs -o nolock,vers=4 192.168.56.11:/nfs/data /mnt/nfs
```

## 三、挂载nfs
```bash
#或者直接写到/etc/fstab文件中
vim /etc/fstab
192.168.56.11:/nfs/data /mnt/nfs/ nfs auto,noatime,nolock,bg,nfsvers=4,intr,tcp,actimeo=1800 0 0

#挂载
mount -a

#卸载挂载
umount /mnt/nfs

#查看nfs服务端信息
nfsstat -s

#查看nfs客户端信息
nfsstat -c
```

参考文档：

http://www.mydlq.club/article/3/  CentOS7 搭建 NFS 服务器

https://blog.rot13.org/2012/05/rpcbind-is-new-portmap-or-how-to-make-nfs-secure.html   

https://yq.aliyun.com/articles/694065

https://www.crifan.com/linux_fstab_and_mount_nfs_syntax_and_parameter_meaning/  Linux中fstab的语法和参数含义和mount NFS时相关参数含义
