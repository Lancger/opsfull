# 一、k8s集群实验环境准备

<table border="0">
    <tr>
        <td><strong>主机名</strong></td>
        <td><strong>IP地址（NAT）</strong></td>
        <td><strong>描述</strong></td>
    </tr>
     <tr>
        <td><strong>linux-node1.example.com</strong></td>
        <td>eth0:192.168.56.11</td>
        <td>Kubernets Master节点/Etcd节点</td>
    </tr>
    <tr>
        <td><strong>linux-node2.example.com</strong></td>
        <td>eth0:192.168.56.12</td>
        <td>Kubernets Node节点/ Etcd节点</td>
    </tr>
    <tr>
        <td><strong>linux-node3.example.com</strong></td>
        <td>eth0:192.168.56.13</td>
        <td>Kubernets Node节点/ Etcd节点</td>
    </tr>
</table>

# 二、约定
## 1.所有文件存放在/opt/kubernetes目录下 

## 2.使用二进制方式进行部署


