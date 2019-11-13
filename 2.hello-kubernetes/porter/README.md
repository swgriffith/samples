# Deploying a Dapr App with OAM and Porter
The following shows the process for deploying a Dapr application using the OAM specification and Rudr onto a Kubernetes cluster. To build this you'll need to install Porter using the instructions found [here](https://porter.sh/install/). I wont dive into all of the details of Porter, OAM and Rudr here, as the respective docs cover that well. See the following:

* [Porter](https://porter.sh/)
* [OAM](https://openappmodel.io/)
* [Rudr](https://github.com/oam-dev/rudr/blob/master/docs/README.md)

To build and deploy this via Porter you'll need to run the following commands (**Note:** Rudr, the Dapr Runtime, and the Dapr app have been kept separate in this implementation, but could be combined.)

#### Rudr Install Bundle
```bash
# Clone the repo
git clone https://github.com/swgriffith/samples.git
cd samples
git checkout porter-oam

# Build the Rudr bundle
cd samples/2.hello-kubernetes/porter/rudr 

# Generate your credentials file, which will ask you to set the fully qualified location of you .kube/config
porter credentials generate rudr-creds 

# Output should look like the following
Generating new credential rudr-creds from bundle rudr-install
==> 1 credentials required for bundle rudr-install
? How would you like to set credential "kubeconfig" file path
? Enter the path that will be used to set credential "kubeconfig" ~/.kube/config
Saving credential to /Users/griffith/.porter/credentials/rudr-creds.yaml

# for debugging issues you can add the --debug flag below
porter build

# Install the Rudr bundle
porter install -c ~/.porter/credentials/rudr-creds.yaml 

# Check installation succeeded
kubectl get pods

# Expected Output
NAME                                            READY   STATUS    RESTARTS   AGE
nginx-ingress-controller-7ddf8dc85d-bcltl       1/1     Running   0          56s
nginx-ingress-default-backend-f5b888f7d-92vn8   1/1     Running   0          56s
rudr-85cc758698-kwrb4                           1/1     Running   0          51s
```

#### Dapr Install Bundle
```bash
cd samples/2.hello-kubernetes/porter/dapr

# If you've already generated the credentials file above you can either reuse that or create a separate one for the dapr install
porter credentials generate dapr-install

# for debugging issues you can add the --debug flag below
porter build

# Install the Dapr App bundle being sure to set a password parameter value for your redis
# NOTE: The following will take a few minutes to complete, as there are pauses built in for the Dapr
# runtime and for Redis to come online.
porter install -c ~/.porter/credentials/dapr-install.yaml --param redisPasswd=<YourRedisPassword>

# Check to make sure your pods deployed successfully
kubectl get pods

# Output should look like the following with the dapr runtimne, nginx, redis and rudr
NAME                                            READY   STATUS    RESTARTS   AGE
dapr-operator-68f7dcb454-jqs82                  1/1     Running   0          2m45s
dapr-placement-6d77d54dc6-p5k4t                 1/1     Running   0          2m45s
dapr-sidecar-injector-86d6ccf956-7mptt          1/1     Running   0          2m45s
nginx-ingress-controller-7ddf8dc85d-bcltl       1/1     Running   0          13m
nginx-ingress-default-backend-f5b888f7d-92vn8   1/1     Running   0          13m
redis-master-0                                  1/1     Running   0          2m16s
redis-slave-0                                   1/1     Running   0          2m16s
redis-slave-1                                   1/1     Running   0          71s
rudr-85cc758698-kwrb4                           1/1     Running   0          12m
```

#### Dapr Demo App Bundle
```bash
cd samples/2.hello-kubernetes/porter/daprdemoapp

# Again, if you've already generated the credentials file above you can either reuse that or create a separate one for the dapr app
porter credentials generate dapr-app-install

# for debugging issues you can add the --debug flag below
porter build

# Install the Dapr App bundle being sure to set a password parameter value for your redis
# NOTE: The following will take a few minutes to complete, as there are pauses built in for the Dapr
# runtime and for Redis to come online.
porter install -c ~/.porter/credentials/dapr-app-install.yaml

# Check to make sure your pods deployed successfully
kubectl get pods

# Output should look like the following with the dapr demo app node and python components now running
NAME                                                READY   STATUS    RESTARTS   AGE
pod/dapr-operator-68f7dcb454-wms7g                  1/1     Running   0          3m43s
pod/dapr-placement-6d77d54dc6-24b7j                 1/1     Running   0          3m43s
pod/dapr-sidecar-injector-86d6ccf956-42frr          1/1     Running   0          3m43s
pod/nginx-ingress-controller-7ddf8dc85d-289pz       1/1     Running   0          27m
pod/nginx-ingress-default-backend-f5b888f7d-xkztz   1/1     Running   0          27m
pod/nodeapp-dapr-86957d6c56-rclnl                   2/2     Running   0          12s
pod/pythonapp-dapr-68989655f6-xzzlr                 2/2     Running   0          12s
pod/redis-master-0                                  1/1     Running   0          2m47s
pod/redis-slave-0                                   1/1     Running   0          2m47s

# Check that the Dapr app is running (Update with your pod id)
kubectl logs nodeapp-dapr-86957d6c56-rclnl -c nodeapp -f

# Output should look like the following:
Node App listening on port 3000!
Got a new order! Order ID: 3
Successfully persisted state
Got a new order! Order ID: 4
Successfully persisted state
Got a new order! Order ID: 5
Successfully persisted state
```

To test if your ingress controller is working you'll need to get your Ingress controller public IP and then add a value to your /etc/hosts file, or equivalent to map your public IP to dapr-demo.oam.io.

```bash
# Get the nginx-ingress-controller EXTERNAL-IP value
kubectl get svc

# Add a row to /etc/hosts like the following
52.255.212.16 dapr-demo.oam.io

# curl the endpoint. This should return an order record.
curl dapr-demo.oam.io/v1.0/invoke/nodeapp/method/order
```

### Cleanup
Both bundles have 'uninstall' implementations, so to remove the app and rudr components you can run the following:
```bash
# Uninstall the Dapr App, from the dapr-app directory
cd samples/2.hello-kubernetes/porter/daprdemoapp
porter uninstall -c ~/.porter/credentials/dapr-app-install.yaml

# Uninstall the Dapr Runtime from the dapr directory
cd samples/2.hello-kubernetes/porter/dapr
porter uninstall -c ~/.porter/credentials/dapr-install.yaml --param redisPasswd=<YourRedisPassword> 

# Uninstall Rudr from the rudr directory
porter uninstall -c ~/.porter/credentials/rudr-creds.yaml  

# Confirm uninstall was clean and that no components are remaining
# Note: The persistent volumes may take some time.
kubectl get pods,svc,pvc,pv
```

### Porter Publish
Part of the beauty of porter is the ability to publish your bundle. Assuming you're signed into a CNAB capable Repository (ex. Docker Hub). First you'll want to update the metadata in the rudr and dapr app porter.yaml files to match your repository info, then you can run the following:

```bash
# From the rudr folder
porter publish

# from the dapr folder
porter publish

# from the daprdemoapp folder
porter publish
```

To install the app using the published bundles
```bash
# Rudr install
porter install -t stevegriffith/rudr-install:0.1.0 -c ~/.porter/credentials/rudr-creds.yaml 

# Dapr Runtime Install
porter install -t stevegriffith/dapr-install:0.1.0 -c ~/.porter/credentials/dapr-install.yaml --param redisPasswd=<YourRedisPassword>

# Dapr Demo App Install
porter install -t stevegriffith/dapr-app-install:0.1.0 -c ~/.porter/credentials/dapr-app-install.yaml
```

To uninstall the app using the published bundles
```bash
# Dapr Demo App Uninstall
porter uninstall -t stevegriffith/dapr-app-install:0.1.0 -c ~/.porter/credentials/dapr-app-install.yaml

# Dapr Runtime Uninstall
porter uninstall -t stevegriffith/dapr-install:0.1.0 -c ~/.porter/credentials/dapr-app-install.yaml --param redisPasswd=<YourRedisPassword>

# Rudr Uninstall
porter uninstall -t stevegriffith/rudr-install:0.1.0 -c ~/.porter/credentials/rudr-creds.yaml 
```