# 环境介绍：

    CentOS： 7.6
    Docker： 18.06.1-ce
    Kubernetes： 1.13.4
    Kuberadm： 1.13.4
    Kuberlet： 1.13.4
    Kuberctl： 1.13.4
    
# 部署介绍：

&#8195;&#8195;创建高可用首先先有一个 Master 节点，然后再让其他服务器加入组成三个 Master 节点高可用，然后再讲工作节点 Node 加入。下面将描述每个节点要执行的步骤：

    Master01： 二、三、四、五、六、七、八、九、十一
    Master02、Master03： 二、三、五、六、四、九
    node01、node02： 二、五、六、九

# 集群架构：


参考资料：

http://www.mydlq.club/article/4/
