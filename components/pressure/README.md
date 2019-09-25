# 一、生产大规模集群，网络组件选择

如果用calico-RR反射器这种模式，保证性能的情况下大概能支撑好多个节点？

RR反射器还分为两种 可以由calico的节点服务承载 也可以是直接的物理路由器做RR

超大规模Calico如果全以BGP来跑没什么问题 只是要做好网络地址规划 即便是不同集群容器地址也不能重叠

# 二、flanel网络组件压测

```
flannel受限于cpu压力
```
  ![k8s网络组件flannel压测](https://github.com/Lancger/opsfull/blob/master/images/pressure_flannel_01.png)

# 三、calico网络组件压测

```
calico则轻轻松松与宿主机性能相差无几

如果单单一个集群 节点数超级多 如果不做BGP路由聚合 物理路由器或三层交换机会扛不住的
```
  ![k8s网络组件calico压测](https://github.com/Lancger/opsfull/blob/master/images/pressure_calico_01.png)

# 四、calico网络和宿主机压测

  ![k8s网络组件压测](https://github.com/Lancger/opsfull/blob/master/images/pressure_physical_01.png)
