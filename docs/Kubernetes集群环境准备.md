# k8s集群实验环境准备

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
        <tr>
        <td><strong>备注</strong></td>
        <td colspan="2">1.如果有条件可以部署多个Kubernets node，实验效果更佳</td>
    </tr>
</table>
