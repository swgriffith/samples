# Clean out the app deployment and the component specs
kubectl delete -f node-app-component.yaml
kubectl delete -f python-app-component.yaml
kubectl delete -f dapr-demo-app-config.yaml
# Remove the deployed Services. Dapr currently does not remove.
kubectl delete svc nodeapp-dapr
kubectl delete svc pythonapp-dapr
# Re-install the components and app
kubectl create -f node-app-component.yaml
kubectl create -f python-app-component.yaml
kubectl create -f dapr-demo-app-config.yaml