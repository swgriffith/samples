kubectl delete -f node-app-component.yaml
kubectl delete -f python-app-component.yaml
kubectl delete -f dapr-demo-app-config.yaml
kubectl create -f node-app-component.yaml
kubectl create -f python-app-component.yaml
kubectl create -f dapr-demo-app-config.yaml