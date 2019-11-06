# 一、创建namespace
```bash
# 创建一个专用的 namespace
cat > mos_namespace.yaml <<\EOF
---
apiVersion: v1
kind: Namespace
metadata:
  name: mos
EOF

kubectl apply -f mos_namespace.yaml

# 查看 namespace
kubectl get namespace -n mos
```
参考文档：

https://www.cnblogs.com/klvchen/p/10862607.html 
