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

Finally, we need the Application Configuration. The app config file is very simple. You just define the configuration name that you're deploying and then specify all of the components that should be included. In this case we're deploying the node app and the python app. For the node app we're going to take advantage of one of the previoulsy defined 'Traits', which are generally managed by IT Operator. The trait we'll use in this case is the 'ingress' trait, which will ensure that our app is wired up to the ingress controller (TODO: Need to fix the ingress controller config).

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