# Deploy a Dapr App with OAM

The following demonstrates the process to take your Dapr app and define and deploy an OAM spec and then deploy to Rudr using the 'Hello Kubernetes' example.

## Setup
First you'll need to set up OAM and Rudr. You can do this by following the guide [here](https://github.com/oam-dev/rudr/blob/master/docs/setup/install.md). The steps are roughly as follows:

1. Clone the Rudr repo
1. Install kubectl (you'll also need access to a Kubernetes cluster)
1. Install Helm 3 (**Note:** If you're new to Helm 3 you should also check out the Helm 2 to 3 migration guide & plugin [here](https://github.com/helm/helm-2to3/blob/master/README.md))

As noted above, you'll also need access to a Kubernetes cluster. You'll also need the Dapr CLI installed locally, and then the dapr components initialized on your kubernetes cluster. You can find those instructions [here](https://github.com/dapr/docs/blob/master/getting-started/environment-setup.md#installing-dapr-on-a-kubernetes-cluster)

In short:
1. Install the Dapr cli
1. Make sure you have your local .kube/config set so you have access to your cluster
1. Run 'dapr init --kubernetes'

## Create and Configure a State Store

Dapr can use a number of different state stores (Redis, CosmosDB, DynamoDB, Cassandra, etc.) to persist and retrieve state. For this demo, we'll use Redis.

1. Follow [these steps](https://github.com/dapr/docs/blob/master/concepts/components/redis.md#creating-a-redis-store) to create a Redis store.
2. Once your store is created, add the keys to the `redis.yaml` file in the `deploy` directory. 
    > **Note:** the `redis.yaml` file provided in this sample takes plain text secrets. In a production-grade application, follow [secret management](https://github.com/dapr/dapr/blob/master/docs/components/secrets.md) instructions to securely manage your secrets.
3. Apply the `redis.yaml` file: `kubectl apply -f redis.yaml` and observe that your state store was successfully configured!

```bash
component.dapr.io "statestore" configured
```

## OAM Spec
OAM provides three specifications geared at three different user types, the Application Developer (Component Specification), Application Operator (Application Configuration) and Infrastructure Operator (Traits). 

### Component Specification
The component specification lays out the sturcture of the application compontents and the definition of the [workload type](https://github.com/oam-dev/spec/blob/master/3.component_model.md#workload-types). In this case our application is a simple nodejs app. The Dapr sidecar will handle exposing the port for internal clsuter communication, however we will also want an external IP that we can call. This external IP will be applied via the ingress controller which is managed by Rudr.

Note that we use annotation to indicate that this app should leverage the dapr runtime, which will ensure the sidecar is applied and the right ports are open. Also notice the workload type is 'Worker'. This is important because it ensures that no Kubernetes Service is created, which would conflict with Dapr managed Service.

```yaml
# node-app-component.yaml
apiVersion: core.oam.dev/v1alpha1
kind: ComponentSchematic
metadata:
  name: nodeapp-v1
  annotations:
    dapr.io/enabled: "true"
    dapr.io/id: "nodeapp"
    dapr.io/port: "3000"  
spec:
  workloadType: core.oam.dev/v1alpha1.Worker
  containers:
    - name: nodeapp
      image: dapriosamples/hello-k8s-node     
      imagePullPolicy: Always

```

Like the node app the python test app will also have the Dapr runtime applied via annoations, however no port need to be exposed from this app, we we can leave that annotation off.

```yaml
# python-app-component.yaml
apiVersion: core.oam.dev/v1alpha1
kind: ComponentSchematic
metadata:
  name: pythonapp-v1
  annotations:
    dapr.io/enabled: "true"
    dapr.io/id: "pythonapp"
spec:
  workloadType: core.oam.dev/v1alpha1.Worker  
  containers:
    - name: python
      image: dapriosamples/hello-k8s-python
      labels:
        app: python    
      imagePullPolicy: Always
```

Finally, we need the Application Configuration. The app config file is very simple. You just define the configuration name that you're deploying and then specify all of the components that should be included. In this case we're deploying the node app and the python app. For the node app we're going to take advantage of one of the previoulsy defined 'Traits', which are generally managed by IT Operator. The trait we'll use in this case is the 'ingress' trait, which will ensure that our app is wired up to the ingress controller.

```yaml
# dapr-demo-app-config.yaml
apiVersion: core.oam.dev/v1alpha1
kind: ApplicationConfiguration
metadata:
  name: dapr-demo
spec:
  components:
  - name: nodeapp-v1
    instanceName: nodeapp-dapr 
    traits:
      - name: ingress
        parameterValues:
          - name: path
            value: / 
          - name: service_port
            value: 80             
  - name: pythonapp-v1
    instanceName: pythonapp-dapr
```

## Deploy the App
To get the app deployed you'll first deploy the Component Specifications and then the Application configuration. 

```bash
kubectl create -f node-app-component.yaml
kubectl create -f python-app-component.yaml
kubectl create -f dapr-demo-app-config.yaml
```

To test the application is working check the logs for the node application. You can do this by getting the pod name and then checking the logs for the 'nodeapp' container in that pod, as follows:

```bash
# Grab the pod id
POD=$(kubectl get pod -l app.kubernetes.io/name=dapr-demo -o jsonpath="{.items[0].metadata.name}")
# Follow the node app logs
kubectl logs $POD -c nodeapp -f

# Output might take a minute but should look like this:
Got a new order! Order ID: 984
Successfully persisted state
Got a new order! Order ID: 985
Successfully persisted state
Got a new order! Order ID: 986
Successfully persisted state
```

Since we added the 'Ingress' trait to this deployment, Rudr wired up the ingress controller to the node app as well. You can curl that endpoint, however since we set a host name we'll need to map that host name to the ingress controler explosed public IP.

```bash
# Get the public IP of the ingress controller
kubectl get svc

# Add a line to your hosts file (ex. /etc/hosts) like the following
<Your Ingress Public IP> dapr-demo.oam.io

# curl the app
curl dapr-demo.oam.io/v1.0/invoke/nodeapp/method/order 
```

And there was much rejoicing.