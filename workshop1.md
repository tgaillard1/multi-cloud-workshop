#   Workshop 1 -- Continuous Integration -- Jenkins 

![Workshop 1 Screenshot](images/jenkins-ci-arch.png?raw=true "Workshop 1 Diagram")

## Prerequisites
*  A Google Cloud Platform Account
*  Set Project
```
gcloud config set project REPLACE_WITH_YOUR_PROJECT_ID 
```
*  Enable API's
```
gcloud services enable \
    container.googleapis.com \
    compute.googleapis.com \
    stackdriver.googleapis.com \
    meshca.googleapis.com \
    meshtelemetry.googleapis.com \
    meshconfig.googleapis.com \
    iamcredentials.googleapis.com \
    anthos.googleapis.com
```

### Create kubernetes Cluster for CI

Get workshop source code 


**NOTE** -- All workshops share the same code so do not repeat if you have already run another workshop
```
git clone https://github.com/tgaillard1/multi-cloud-workshop.git
cd multi-cloud-workshop/
source ./env
```

Deploy Cluster
```
gcloud beta container clusters create ${CLUSTER_NAME1} \
    --machine-type=${NODE_SIZE} \
    --num-nodes=${NODE_COUNT} \
    --identity-namespace=${IDNS} \
    --enable-stackdriver-kubernetes \
    --subnetwork=default \
    --labels mesh_id=${MESH_ID} \
    --zone ${CLUSTER_ZONE1} \
    --scopes "https://www.googleapis.com/auth/source.read_write,cloud-platform"
```

Once that operation completes download the credentials for your cluster using the gcloud CLI and confirm cluster is running:
```
gcloud container clusters get-credentials ${CLUSTER_NAME1} --zone ${CLUSTER_ZONE1}
kubectl get pods

You should see "No resources found"
```

### Add Config Management

Anthos Nomos Install
```
gsutil cp gs://config-management-release/released/latest/linux_amd64/nomos $WORKDIR/nomos
chmod +x $WORKDIR/nomos
sudo cp $WORKDIR/nomos /usr/local/bin/nomos
```

Intall Kustomize
```
opsys=linux
curl -s https://api.github.com/repos/kubernetes-sigs/kustomize/releases/latest |\
  grep browser_download |\
  grep $opsys |\
  cut -d '"' -f 4 |\
  xargs curl -L -o $WORKDIR/kustomize

sudo chmod +x $WORKDIR/kustomize
sudo cp $WORKDIR/kustomize /usr/local/bin/kustomize
```

### Create Git Hub Config Management Repo

Create Git Hub Repo
Login to your Git Hub account --> got to repositories --> select "New" --> Enter variables below:
+ Repository Name = config-mgmt-repo
+ Description = Config Management for multi-cloud
+ --> Creat Repository

Copy Repo URL link and enter below

Create Input Variable for Config Management
```
export REPO="config-mgmt-repo"
export ACCOUNT=YOUR_GIT_USER
export REPO_URL=https://github.com/${ACCOUNT}/${REPO}.git
```

Initialize for Git Push
```
cd $HOME
cp -rf $BASE_DIR/config-mgmt-repo/ .
cd anthos-config-mgmt/
git init
git config credential.helper
git remote add origin $REPO_URL
```

Push Files to Git Repo
```
git add .
git commit -m "Initial commit"
git push origin master
```

### Add deployment key to GIT repo
```
ssh-keygen -t rsa -b 4096 \
 -C "${ACCOUNT}" \
 -N '' \
 -f ${HOME}/.ssh/config-mgmt-key
```

Go to Git -- Repo --> config-mgmt-repo --> settings --> Deploy keys --> Add deploy key

--> Add a **Title** = config-mgmt-deploy-key

--> Copy contents of public key from command below to **Key** location:
```
cat ${HOME}/.ssh/config-mgmt-key.pub
```

--> Allow write access to GitHub

--> Add key


### Rename context and set configuration
```
kubectx ${CLUSTER_NAME1}=gke_${PROJECT_ID}_${CLUSTER_ZONE1}_${CLUSTER_NAME1}
```

Create cluster admin binding
```
kubectl create clusterrolebinding cluster-admin-binding \
  --clusterrole cluster-admin \
  --user="$(gcloud config get-value core/account)"
```

Obtain and deploy operator for Jenkins
```
gsutil cp gs://config-management-release/released/latest/config-management-operator.yaml config-management-operator.yaml
```

```
kubectl apply -f config-management-operator.yaml
```

Create credentials for kubernetes
```
kubectl create secret generic git-creds \
--namespace=config-management-system \
--from-file=ssh=${HOME}/.ssh/config-mgmt-key
```

### Create Config Management for Kubernetes

```
cat > $BASE_DIR/config-management-${CLUSTER_NAME1}.yaml  <<EOF
apiVersion: configmanagement.gke.io/v1
kind: ConfigManagement
metadata:
  name: config-management
spec:
  # clusterName is required and must be unique among all managed clusters
  clusterName: ${CLUSTER_NAME1}
  git:
    syncRepo: git@github.com:${ACCOUNT}/${REPO}.git
    syncBranch: master
    secretType: ssh
    policyDir: "."
EOF
```

Apply config management to kubernetes
```
kubectl apply -f $BASE_DIR/config-management-${CLUSTER_NAME1}.yaml
```

Validate install

```
nomos status to validate | grep ${CLUSTER_NAME1} --> SYNCED
```

### Adding Anthos Service Mesh

Validate download and authorize Anthos Service Mesh

```
curl --request POST \
--header "Authorization: Bearer $(gcloud auth print-access-token)" \
--data '' \
https://meshconfig.googleapis.com/v1alpha1/projects/${PROJECT_ID}:initialize
```

```
curl -Lo $WORKDIR/istio-1.4.6-asm.0-linux.tar.gz https://storage.googleapis.com/gke-release/asm/istio-1.4.6-asm.0-linux.tar.gz

curl -Lo $WORKDIR/istio-1.4.6-asm.0-linux.tar.gz.1.sig https://storage.googleapis.com/gke-release/asm/istio-1.4.6-asm.0-linux.tar.gz.1.sig
openssl dgst -verify - -signature $WORKDIR/istio-1.4.6-asm.0-linux.tar.gz.1.sig $WORKDIR/istio-1.4.6-asm.0-linux.tar.gz <<'EOF'
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEWZrGCUaJJr1H8a36sG4UUoXvlXvZ
wQfk16sxprI2gOJ2vFFggdq3ixF2h4qNBt0kI7ciDhgpwS8t+/960IsIgw==
-----END PUBLIC KEY-----
EOF
```

Unpackage asm
```
cd $WORKDIR/
tar xzf istio-1.4.6-asm.0-linux.tar.gz

cd $WORKDIR/istio-1.4.6-asm.0
```

Set Path for asm
```
export PATH=$PWD/bin:$PATH
```

Initiate install of asm
```
istioctl manifest apply --set profile=asm \
  --set values.global.trustDomain=${IDNS} \
  --set values.global.sds.token.aud=${IDNS} \
  --set values.nodeagent.env.GKE_CLUSTER_URL=https://container.googleapis.com/v1/projects/${PROJECT_ID}/locations/${CLUSTER_ZONE1}/clusters/${CLUSTER_NAME1} \
  --set values.global.meshID=${MESH_ID} \
  --set values.global.proxy.env.GCP_METADATA="${PROJECT_ID}|${PROJECT_NUMBER}|${CLUSTER_NAME1}|${CLUSTER_ZONE1}"
```

Validate Install
```
kubectl wait --for=condition=available --timeout=600s deployment --all -n istio-system
```

This should return:
**deployment.extensions/istio-galley condition met**
**deployment.extensions/istio-ingressgateway condition met**
**deployment.extensions/istio-pilot condition met**
**deployment.extensions/istio-sidecar-injector condition met**
**deployment.extensions/promsd condition met**


Change labels to ensure Istio/Envoy is deployed as sidecar
    ```
    kubectl label namespace default istio-injection=enabled --overwrite
    ```

------
### Install Helm

1. Download and install the helm binary -- Unzip the file to your local system:

    ```
    wget https://storage.googleapis.com/kubernetes-helm/helm-$HELM_VERSION-linux-amd64.tar.gz -P $WORKDIR/
    tar -xvzf $WORKDIR/helm-$HELM_VERSION-linux-amd64.tar.gz -C $WORKDIR/ 
    mv $WORKDIR/linux-amd64 $HELM_PATH
    ```

1. Grant Tiller, the server side of Helm, the cluster-admin role in your cluster:

    ```
    kubectl create serviceaccount tiller --namespace kube-system
    kubectl create clusterrolebinding tiller-admin-binding --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
    ```

1. Initialize Helm. This ensures that the server side of Helm (Tiller) is properly installed in your cluster.

    ```
    helm init --service-account=tiller
    helm update
    ```

1. Ensure Helm is properly installed by running the following command. You should see versions appear for both the server and the client of ```v2.14.1```:

    ```shell
    helm version
    Client: &version.Version{SemVer:"v2.14.1", GitCommit:"5270352a09c7e8b6e8c9593002a73535276507c0", GitTreeState:"clean"}
    Server: &version.Version{SemVer:"v2.14.1", GitCommit:"5270352a09c7e8b6e8c9593002a73535276507c0", GitTreeState:"clean"}
    ```


### Configure and Install Jenkins
You will use a custom [values file](https://github.com/kubernetes/helm/blob/master/docs/chart_template_guide/values_files.md) to add the GCP specific plugin necessary to use service account credentials to reach your Cloud Source Repository.

1. Use the Helm CLI to deploy the chart with your configuration set.

    ```shell
    helm install -n cd stable/jenkins -f $BASE_DIR/continuous-integration-on-kubernetes/jenkins/values.yaml --version 1.2.2 --wait
    ```

1. Once that command completes ensure the Jenkins pod goes to the `Running` state and the container is in the `READY` state:

    ```shell
    kubectl get pods
    NAME                          READY     STATUS    RESTARTS   AGE
    cd-jenkins-7c786475dd-vbhg4   1/1       Running   0          1m
    ```
    
1. Configure the Jenkins service account to be able to deploy to the cluster. 

    ```shell
    kubectl create clusterrolebinding jenkins-deploy --clusterrole=cluster-admin --serviceaccount=default:cd-jenkins

    clusterrolebinding.rbac.authorization.k8s.io/jenkins-deploy created
    ```

1. Run the following command to setup port forwarding to the Jenkins UI from the Cloud Shell

    ```shell
    export POD_NAME=$(kubectl get pods -l "app.kubernetes.io/component=jenkins-master" -o jsonpath="{.items[0].metadata.name}")
    kubectl port-forward $POD_NAME 8080:8080 >> /dev/null &
    ```

1. Now, check that the Jenkins Service was created properly:

    ```shell
    $ kubectl get svc
    NAME               CLUSTER-IP     EXTERNAL-IP   PORT(S)     AGE
    cd-jenkins         10.35.249.67   <none>        8080/TCP    3h
    cd-jenkins-agent   10.35.248.1    <none>        50000/TCP   3h
    kubernetes         10.35.240.1    <none>        443/TCP     9h
    ```

We are using the [Kubernetes Plugin](https://wiki.jenkins-ci.org/display/JENKINS/Kubernetes+Plugin) so that our builder nodes will be automatically launched as necessary when the Jenkins master requests them.
Upon completion of their work they will automatically be turned down and their resources added back to the clusters resource pool.

Notice that this service exposes ports `8080` and `50000` for any pods that match the `selector`. This will expose the Jenkins web UI and builder/agent registration ports within the Kubernetes cluster.
Additionally the `jenkins-ui` services is exposed using a ClusterIP so that it is not accessible from outside the cluster.

## Connect to Jenkins

1. The Jenkins chart will automatically create an admin password for you. To retrieve it, run:

    ```shell
    printf $(kubectl get secret cd-jenkins -o jsonpath="{.data.jenkins-admin-password}" | base64 --decode);echo
    ```

2. To get to the Jenkins user interface, click on the Web Preview button![](../docs/img/web-preview.png) in cloud shell, then click “Preview on port 8080”:

![](docs/img/preview-8080.png)

You should now be able to log in with username `admin` and your auto generated password.

![](docs/img/jenkins-login.png)

### Your progress, and what's next
You've got a Kubernetes cluster managed by Google Container Engine. You've deployed:

* a Jenkins Deployment
* a (non-public) service that exposes Jenkins to its agent containers

You have the tools to build a continuous deployment pipeline. Now you need a sample app to deploy continuously.

## The sample app
You'll use a very simple sample application - `gceme` - as the basis for your CD pipeline. `gceme` is written in Go and is located in the `sample-app` directory in this repo. When you run the `gceme` binary on a GCE instance, it displays the instance's metadata in a pretty card:

![](docs/img/info_card.png)

The binary supports two modes of operation, designed to mimic a microservice. In backend mode, `gceme` will listen on a port (8080 by default) and return GCE instance metadata as JSON, with content-type=application/json. In frontend mode, `gceme` will query a backend `gceme` service and render that JSON in the UI you saw above. It looks roughly like this:

```
-----------      ------------      ~~~~~~~~~~~~        -----------
|         |      |          |      |          |        |         |
|  user   | ---> |   gceme  | ---> | lb/proxy | -----> |  gceme  |
|(browser)|      |(frontend)|      |(optional)|   |    |(backend)|
|         |      |          |      |          |   |    |         |
-----------      ------------      ~~~~~~~~~~~~   |    -----------
                                                  |    -----------
                                                  |    |         |
                                                  |--> |  gceme  |
                                                       |(backend)|
                                                       |         |
                                                       -----------
```
Both the frontend and backend modes of the application support two additional URLs:

1. `/version` prints the version of the binary (declared as a const in `main.go`)
1. `/healthz` reports the health of the application. In frontend mode, health will be OK if the backend is reachable.


### Create a repository for the sample app source
Here you'll create your own copy of the `gceme` sample app in [Cloud Source Repository](https://cloud.google.com/source-repositories/docs/).

1. Change directories to `sample-app` of the repo you cloned previously, then initialize the git repository.

   **Be sure to replace _REPLACE_WITH_YOUR_PROJECT_ID_ with the name of your Google Cloud Platform project**

    ```shell
    $ cd sample-app
    $ git init
    $ git config credential.helper gcloud.sh
    $ gcloud source repos create gceme
    $ git remote add origin https://source.developers.google.com/p/REPLACE_WITH_YOUR_PROJECT_ID/r/gceme
    git remote add origin https://source.developers.google.com/p/tgproject1-221717/r/gceme
    ```
    
1. Ensure git is able to identify you:

    ```shell
    $ git config --global user.email "YOUR-EMAIL-ADDRESS"
    $ git config --global user.name "YOUR-NAME"
    ```

1. Add, commit, and push all the files:

    ```shell
    $ git add .
    $ git commit -m "Initial commit"
    $ git push origin master
    ```

Go to --> https://source.cloud.google.com/REPLACE_WITH_YOUR_PROJECT_ID/gceme

```
cd sample-app
kubectl create ns production
kubectl label namespace production istio-injection=enabled --overwrite
```

```
kubectl --namespace=production apply -f k8s/production
kubectl --namespace=production apply -f k8s/canary
kubectl --namespace=production apply -f k8s/services
```

```
kubectl --namespace=production scale deployment gceme-frontend-production --replicas=4
```

```
kubectl --namespace=production get service gceme-frontend
```

```
export FRONTEND_SERVICE_IP=$(kubectl get -o jsonpath="{.status.loadBalancer.ingress[0].ip}"  --namespace=production services gceme-frontend)
while true; do curl http://$FRONTEND_SERVICE_IP/version; sleep 1;  done
```