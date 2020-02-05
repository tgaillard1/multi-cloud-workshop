#   Multi-Cloud Workshop  
### Reference Implementation main document --> go/...

![Workshop Screenshot](images/multi-cloud-workshop.png?raw=true "Workshop Diagram")

## Prerequisites
1. A Google Cloud Platform Account
1. [Enable the Compute Engine, Container Engine, and Container Builder APIs](https://console.cloud.google.com/flows/enableapi?apiid=compute_component,container,cloudbuild.googleapis.com)

Set Project and Zone
```
gcloud config set project REPLACE_WITH_YOUR_PROJECT_ID 
gcloud config set compute/zone YOUR_ZONE
```

Get All Workshop source code
```
git clone https://github.com/tgaillard1/multi-cloud-workshop.git
cd multi-cloud-workshop/
```

******************************************************
## Workshop 1 -- CI Jenkins
******************************************************

Create kubernetes Cluster for CI/CD
```
cd continuous-integration-on-kubernetes

gcloud container clusters create jenkins-ci \
--num-nodes 2 \
--machine-type n1-standard-2 \
--scopes "https://www.googleapis.com/auth/source.read_write,cloud-platform" \
--cluster-version 1.13
```

Once that operation completes download the credentials for your cluster using the gcloud CLI and confirm cluster is running:
```
gcloud container clusters get-credentials jenkins-ci
kubectl get pods

You should see "No resources found"
```

# Install Helm

In this lab, you will use Helm to install Jenkins from the Charts repository. Helm is a package manager that makes it easy to configure and deploy Kubernetes applications.  Once you have Jenkins installed, you'll be able to set up your CI/CD pipleline.

1. Download and install the helm binary

    ```
    wget https://storage.googleapis.com/kubernetes-helm/helm-v2.14.1-linux-amd64.tar.gz
    ```

1. Unzip the file to your local system:

    ```
    tar zxfv helm-v2.14.1-linux-amd64.tar.gz
    cp linux-amd64/helm .
    ```

1. Add yourself as a cluster administrator in the cluster's RBAC so that you can give Jenkins permissions in the cluster:
    
    ```
    kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=$(gcloud config get-value account)
    ```

1. Grant Tiller, the server side of Helm, the cluster-admin role in your cluster:

    ```
    kubectl create serviceaccount tiller --namespace kube-system
    kubectl create clusterrolebinding tiller-admin-binding --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
    ```

1. Initialize Helm. This ensures that the server side of Helm (Tiller) is properly installed in your cluster.

    ```
    ./helm init --service-account=tiller
    ./helm update
    ```

1. Ensure Helm is properly installed by running the following command. You should see versions appear for both the server and the client of ```v2.14.1```:

    ```shell
    ./helm version
    Client: &version.Version{SemVer:"v2.14.1", GitCommit:"5270352a09c7e8b6e8c9593002a73535276507c0", GitTreeState:"clean"}
    Server: &version.Version{SemVer:"v2.14.1", GitCommit:"5270352a09c7e8b6e8c9593002a73535276507c0", GitTreeState:"clean"}
    ```

## Configure and Install Jenkins
You will use a custom [values file](https://github.com/kubernetes/helm/blob/master/docs/chart_template_guide/values_files.md) to add the GCP specific plugin necessary to use service account credentials to reach your Cloud Source Repository.

1. Use the Helm CLI to deploy the chart with your configuration set.

    ```shell
    ./helm install -n cd stable/jenkins -f jenkins/values.yaml --version 1.2.2 --wait
    ```

1. Once that command completes ensure the Jenkins pod goes to the `Running` state and the container is in the `READY` state:

    ```shell
    $ kubectl get pods
    NAME                          READY     STATUS    RESTARTS   AGE
    cd-jenkins-7c786475dd-vbhg4   1/1       Running   0          1m
    ```
    
1. Configure the Jenkins service account to be able to deploy to the cluster. 

    ```shell
    $ kubectl create clusterrolebinding jenkins-deploy --clusterrole=cluster-admin --serviceaccount=default:cd-jenkins
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

### Create GIT OPTION ----  repository for the sample app source

******************************************************
## Workshop 2 -- CD Spinnaker
******************************************************

## Prerequisites
1. A Google Cloud Platform Account
1. [Enable the Cloud Build and Cloud Source Repositories APIs](https://console.cloud.google.com/flows/enableapi?apiid=container,cloudbuild.googleapis.com,sourcerepo.googleapis.com&redirect=https://console.cloud.google.com&_ga=2.48886959.843635228.1580750081-768538728.1545413763)

Set Project and Zone
```
gcloud config set project REPLACE_WITH_YOUR_PROJECT_ID 
gcloud config set compute/zone YOUR_ZONE
```

Create Spinnaker Home
```
mkdir $HOME/spinnaker
cd $HOME/spinnaker
WORKDIR=$(pwd)
```

Install Helm -- * NOTE --- Skip this step if you have already completed it in Workshop 1 *
```
HELM_VERSION=v2.13.0
HELM_PATH="$WORKDIR"/helm-"$HELM_VERSION"
wget https://storage.googleapis.com/kubernetes-helm/helm-"$HELM_VERSION"-linux-amd64.tar.gz
tar -xvzf helm-"$HELM_VERSION"-linux-amd64.tar.gz
mv linux-amd64 "$HELM_PATH"
```

Install kubectx and kubens
```
git clone https://github.com/ahmetb/kubectx $WORKDIR/kubectx
export PATH=$PATH:$WORKDIR/kubectx
```

Install Spin
```
curl -LO https://storage.googleapis.com/spinnaker-artifacts/spin/1.5.2/linux/amd64/spin
chmod +x spin
```

Create GKE clusters
```
gcloud container clusters create spinnaker --zone us-west2-a \
    --num-nodes 3 --machine-type n1-standard-2 --async
gcloud container clusters create west --zone us-west2-b \
    --num-nodes 3 --machine-type n1-standard-2 --async
gcloud container clusters create east --zone us-east4-a \
    --num-nodes 3 --machine-type n1-standard-2

#Validate they are running

gcloud container clusters list
```

Connect to all three clusters 
```
export PROJECT_ID=$(gcloud info --format='value(config.project)')
gcloud container clusters get-credentials east --zone us-east4-a --project ${PROJECT_ID}
gcloud container clusters get-credentials west --zone us-west2-b --project ${PROJECT_ID}
gcloud container clusters get-credentials spinnaker --zone us-west2-a --project ${PROJECT_ID}

#Rename clusters

kubectx east=gke_${PROJECT_ID}_us-east4-a_east
kubectx west=gke_${PROJECT_ID}_us-west2-b_west
kubectx spinnaker=gke_${PROJECT_ID}_us-west2-a_spinnaker
```

Set permissions for cluster-admin
```
kubectl create clusterrolebinding user-admin-binding \
    --clusterrole=cluster-admin \
    --user=$(gcloud config get-value account) \
    --context spinnaker
kubectl create clusterrolebinding user-admin-binding \
    --clusterrole=cluster-admin \
    --user=$(gcloud config get-value account) \
    --context west
kubectl create clusterrolebinding user-admin-binding \
    --clusterrole=cluster-admin \
    --user=$(gcloud config get-value account) \
    --context east
```

Create Service Account
```
gcloud iam service-accounts create spinnaker --display-name spinnaker-service-account

SPINNAKER_SA_EMAIL=$(gcloud iam service-accounts list \
    --filter="displayName:spinnaker-service-account" \
    --format='value(email)')
```

Bind storage.admin and storage.objectAdmin roles
```
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --role roles/storage.admin \
    --member serviceAccount:${SPINNAKER_SA_EMAIL}
gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --role roles/storage.objectAdmin \
    --member serviceAccount:${SPINNAKER_SA_EMAIL}
```

Download Service Account
```
gcloud iam service-accounts keys create $WORKDIR/spinnaker-service-account.json --iam-account ${SPINNAKER_SA_EMAIL}
```

Create Pub/Sub
```
gcloud pubsub topics create projects/${PROJECT_ID}/topics/gcr

gcloud pubsub subscriptions create gcr-triggers \
    --topic projects/${PROJECT_ID}/topics/gcr

gcloud projects add-iam-policy-binding ${PROJECT_ID} \
    --role roles/pubsub.subscriber \
    --member serviceAccount:${SPINNAKER_SA_EMAIL}
```

Deploy Spinnaker
```
kubectx spinnaker
kubectl create serviceaccount tiller --namespace kube-system
kubectl create clusterrolebinding tiller-admin-binding \
    --clusterrole=cluster-admin --serviceaccount=kube-system:tiller

#Deploy Using Helm

${HELM_PATH}/helm init --service-account=tiller
${HELM_PATH}/helm update

${HELM_PATH}/helm version
```

Configure Spinnaker
#Configure bucket
```
export PROJECT_ID=$(gcloud info --format='value(config.project)')
export BUCKET=${PROJECT_ID}-spinnaker-config
gsutil mb -c regional -l us-west2 gs://${BUCKET}
```

Create configuration file for Spinnaker
```
export SA_JSON=$(cat $WORKDIR/spinnaker-service-account.json)
export PROJECT_ID=$(gcloud info --format='value(config.project)')
export BUCKET=${PROJECT_ID}-spinnaker-config

cat > spinnaker-config.yaml <<EOF
gcs:
  enabled: true
  bucket: $BUCKET
  project: $PROJECT_ID
  jsonKey: '$SA_JSON'

dockerRegistries:
- name: gcr
  address: https://gcr.io
  username: _json_key
  password: '$SA_JSON'
  email: 1234@5678.com

# Disable minio as the default storage backend
minio:
  enabled: false

jenkins:
  enabled: false

# Configure Spinnaker to enable GCP services
halyard:
  spinnakerVersion: 1.12.5
  image:
    tag: 1.16.0
  additionalScripts:
    create: true
    data:
      enable_gcs_artifacts.sh: |-
        \$HAL_COMMAND config artifact gcs account add gcs-$PROJECT_ID --json-path /opt/gcs/key.json
        \$HAL_COMMAND config artifact gcs enable
      enable_pubsub_triggers.sh: |-
        \$HAL_COMMAND config pubsub google enable
        \$HAL_COMMAND config pubsub google subscription add gcr-triggers \
          --subscription-name gcr-triggers \
          --json-path /opt/gcs/key.json \
          --project $PROJECT_ID \
          --message-format GCR
EOF
```

Deploy Spinnaker chart
```
${HELM_PATH}/helm install -n spin stable/spinnaker -f spinnaker-config.yaml --timeout 600 \
--version 1.8.1 --wait
```


******************************************************
Adding Kubernetes clusters to Spinnaker
******************************************************

Create Kubernetes service accounts for Spinnaker
```
cat > spinnaker-sa.yaml <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: spinnaker
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
 name: spinnaker-role
rules:
- apiGroups: [""]
  resources: ["namespaces", "configmaps", "events", "replicationcontrollers", "serviceaccounts", "pods/log"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["pods", "services", "secrets"]
  verbs: ["create", "delete", "deletecollection", "get", "list", "patch", "update", "watch"]
- apiGroups: ["autoscaling"]
  resources: ["horizontalpodautoscalers"]
  verbs: ["list", "get"]
- apiGroups: ["apps"]
  resources: ["controllerrevisions", "statefulsets"]
  verbs: ["list"]
- apiGroups: ["extensions", "apps"]
  resources: ["deployments", "replicasets", "ingresses"]
  verbs: ["create", "delete", "deletecollection", "get", "list", "patch", "update", "watch"]
# These permissions are necessary for halyard to operate. We also use this role to deploy Spinnaker.
- apiGroups: [""]
  resources: ["services/proxy", "pods/portforward"]
  verbs: ["create", "delete", "deletecollection", "get", "list", "patch", "update", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
 name: spinnaker-role-binding
roleRef:
 apiGroup: rbac.authorization.k8s.io
 kind: ClusterRole
 name: spinnaker-role
subjects:
- namespace: spinnaker
  kind: ServiceAccount
  name: spinnaker-service-account
---
apiVersion: v1
kind: ServiceAccount
metadata:
 name: spinnaker-service-account
 namespace: spinnaker
EOF
```

Apply Kubernetes authentication

```
kubectl --context west apply -f spinnaker-sa.yaml
kubectl --context east apply -f spinnaker-sa.yaml
```

Get the east and west cluster names, and the Kubernetes service account:

```
WEST_CLUSTER=gke_${PROJECT_ID}_us-west2-b_west
EAST_CLUSTER=gke_${PROJECT_ID}_us-east4-a_east
WEST_USER=west-spinnaker-service-account
EAST_USER=east-spinnaker-service-account
```

Get the tokens from spinnaker-service-account for both east and west clusters:

```
WEST_TOKEN=$(kubectl --context west get secret \
    $(kubectl get serviceaccount spinnaker-service-account \
    --context west \
    -n spinnaker \
    -o jsonpath='{.secrets[0].name}') \
    -n spinnaker \
    -o jsonpath='{.data.token}' | base64 --decode)
EAST_TOKEN=$(kubectl --context east get secret \
    $(kubectl get serviceaccount spinnaker-service-account \
    --context east \
    -n spinnaker \
    -o jsonpath='{.secrets[0].name}') \
    -n spinnaker \
    -o jsonpath='{.data.token}' | base64 --decode)
```

Get the cluster CA for east and west clusters:

```
kubectl config view --raw -o json | jq -r '.clusters[] | select(.name == "'$WEST_CLUSTER'") | .cluster."certificate-authority-data"' | base64 -d > west_cluster_ca.crt
kubectl config view --raw -o json | jq -r '.clusters[] | select(.name == "'$EAST_CLUSTER'") | .cluster."certificate-authority-data"' | base64 -d > east_cluster_ca.crt
```

Get the Kubernetes API server address for the east and west clusters:

```
WEST_SERVER=$(kubectl config view --raw -o json | jq -r '.clusters[] | select(.name == "'$WEST_CLUSTER'") | .cluster."server"')
EAST_SERVER=$(kubectl config view --raw -o json | jq -r '.clusters[] | select(.name == "'$EAST_CLUSTER'") | .cluster."server"')
```

Create a kubeconfig file for Spinnaker:

```
KUBECONFIG_FILE=spinnaker-kubeconfig
```

Populate the spinnaker-kubeconfig file with the east and west clusters by using the values you just retrieved:

```
kubectl config --kubeconfig=$KUBECONFIG_FILE set-cluster $WEST_CLUSTER \
    --certificate-authority=$WORKDIR/west_cluster_ca.crt \
    --embed-certs=true \
    --server $WEST_SERVER
kubectl config --kubeconfig=$KUBECONFIG_FILE set-credentials $WEST_USER --token $WEST_TOKEN
kubectl config --kubeconfig=$KUBECONFIG_FILE set-context west --user $WEST_USER --cluster $WEST_CLUSTER
kubectl config --kubeconfig=$KUBECONFIG_FILE set-cluster $EAST_CLUSTER \
    --certificate-authority=$WORKDIR/east_cluster_ca.crt \
    --embed-certs=true \
    --server $EAST_SERVER
kubectl config --kubeconfig=$KUBECONFIG_FILE set-credentials $EAST_USER --token $EAST_TOKEN
kubectl config --kubeconfig=$KUBECONFIG_FILE set-context east --user $EAST_USER --cluster $EAST_CLUSTER
```

Create a Kubernetes secret in the spinnaker cluster:

```
kubectx spinnaker
kubectl create secret generic --from-file=$WORKDIR/spinnaker-kubeconfig spin-kubeconfig
```

Update the spinnaker-config.yaml file by appending a section for kubeconfig to add the additional clusters:

```
cat >> spinnaker-config.yaml <<EOF
kubeConfig:
  enabled: true
  secretName: spin-kubeconfig
  secretKey: spinnaker-kubeconfig
  contexts:
  - east
  - west
EOF
```

Update the Spinnaker helm release:

```
${HELM_PATH}/helm upgrade spin stable/spinnaker -f spinnaker-config.yaml --timeout 600 --version 1.8.1 --wait
```
************************
************************
************************

Validate deployments

************************
************************
************************

************************ Reset Variables if not in one deployment -- Make sure Pub/Sub was not deleted ************************

gcloud config set project tgproject1-221717
cd $HOME/spinnaker
WORKDIR=$(pwd)
chmod +x spin
export PATH=$PATH:$WORKDIR/kubectx
export PROJECT_ID=$(gcloud info --format='value(config.project)')
${HELM_PATH}/helm version
HELM_VERSION=v2.13.0
HELM_PATH="$WORKDIR"/helm-"$HELM_VERSION"
${HELM_PATH}/helm version
export SA_JSON=$(cat $WORKDIR/spinnaker-service-account.json)
export PROJECT_ID=$(gcloud info --format='value(config.project)')
export BUCKET=${PROJECT_ID}-spinnaker-config

************************ Reset Variables if not in one deployment ************************


```
kubectl get pods
```

Set up port forwarding to the Spinnaker UI from Cloud Shell:

```
export DECK_POD=$(kubectl get pods --namespace default -l "cluster=spin-deck" \
    -o jsonpath="{.items[0].metadata.name}")
kubectl port-forward --namespace default $DECK_POD 8080:9000 >> /dev/null &
```
To open the Spinnaker user interface, in Cloud Shell, click Web Preview, and then click Preview on port 8080.

In Cloud Shell, download and unpack the sample source code:

```
wget https://gke-spinnaker.storage.googleapis.com/sample-app-v3.tgz
tar xzfv sample-app-v3.tgz
cd sample-app
```

```
export EMAIL=$(gcloud config get-value account)
git config --global user.email "$EMAIL"
git config --global user.name "$USER"
```

Make the initial commit to your source code repository:
```
git init
git add .
git commit -m "Initial commit"
```

Create a repository to host your code:

```
gcloud source repos create sample-app
```

Add your new repository as remote, and push your code to the master branch of the remote repository:

```
git remote add origin https://source.developers.google.com/p/$PROJECT_ID/r/sample-app
git push origin master
```

View Source code

```
https://console.cloud.google.com/code/develop/browse/sample-app/master?_ga=2.22785213.-768538728.1545413763
```

In the GCP Console, go to Cloud Build > Create trigger:

GO TO THE CREATE TRIGGER PAGE -- https://console.cloud.google.com/gcr/triggers/add?_ga=2.17002047.-768538728.1545413763

Select Cloud Source Repository, and then click Continue.

Select your new sample-app repository from the list, and click Continue.

Enter the following trigger settings:

Name: sample-app-tags
Trigger type: Tag
Tag (regex): v.*
Build configuration: Select Cloud Build configuration file (yaml or json)
Cloud Build configuration file location: cloudbuild.yaml
Click Create trigger.

***
In Cloud Shell, create a bucket and enable versioning on the bucket so that you have a history of your manifests:

```
cd $WORKDIR/sample-app
export PROJECT_ID=$(gcloud info --format='value(config.project)')
gsutil mb -l us-west2 gs://$PROJECT_ID-kubernetes-manifests
gsutil versioning set on gs://$PROJECT_ID-kubernetes-manifests
```

Set the correct project ID in your Kubernetes deployment manifests and commit the changes to the repository:

```
sed -i s/PROJECT/$PROJECT_ID/g k8s/deployments/*
git commit -a -m "Set project ID"
```

Push your first image by creating a git tag and pushing the tag to the repository:

```
git tag v1.5.0
git push --tags

#Verify build is pushed by going to Cloud Build --> History
```

******************************************************
Create a multi-cluster deployment pipeline
******************************************************

Use spin to create an application in Spinnaker:

```
cd $WORKDIR
./spin application save --application-name sample \
    --owner-email example@example.com \
    --cloud-providers kubernetes \
    --gate-endpoint http://localhost:8080/gate
```

Run the following commands to upload an example pipeline to your Spinnaker instance:

```
cd $WORKDIR/sample-app
export PROJECT_ID=$(gcloud info --format='value(config.project)')
export GKE_ONE=west
export REGION_ONE=West
export GKE_TWO=east
export REGION_TWO=East
sed -e s/GKE_ONE/$GKE_ONE/g -e s/REGION_ONE/$REGION_ONE/g -e s/GKE_TWO/$GKE_TWO/g -e s/REGION_TWO/$REGION_TWO/g -e s/PROJECT_ID/$PROJECT_ID/g $WORKDIR/sample-app/spinnaker/pipeline-deploy-multicluster.json > $WORKDIR/sample-app/multicluster-pipeline-deploy.json
cd $WORKDIR
./spin pipeline save --gate-endpoint http://localhost:8080/gate -f $WORKDIR/sample-app/multicluster-pipeline-deploy.json
```

Create a tag and push the image to Cloud Source Repositories to trigger the Spinnaker pipeline:

```
cd $WORKDIR/sample-app
git tag v1.5.1
git push --tags
```

******************************************************
Triggering your pipeline from code changes

In Cloud Shell, change the color of the app from red to blue:
```
cd $WORKDIR/sample-app
sed -i 's/red/blue/g' cmd/gke-info/common-service.go
```

```
git commit -a -m "Change color to blue"
git tag v1.1.2
git push --tags
```

****
Change image from blue to orange
```
cd $WORKDIR/sample-app
sed -i 's/blue/orange/g' cmd/gke-info/common-service.go
```

```
git commit -a -m "Change color to orange"
git tag v1.5.3
git push --tags
```


******************************************************
******************************************************
Delete the GKE clusters:
```
gcloud container clusters delete spinnaker --zone us-west2-a --quiet --async
gcloud container clusters delete west --zone us-west2-b --quiet --async
gcloud container clusters delete east --zone us-east4-a --quiet --async
```

Delete the context for the three clusters from your kubeconfig file:
```
kubectx -d spinnaker
kubectx -d east
kubectx -d west
```

Delete the spinnaker GCP service account:
```
SPINNAKER_SA_EMAIL=$(gcloud iam service-accounts list \
    --filter="displayName:spinnaker-service-account" \
    --format='value(email)')
gcloud iam service-accounts delete $SPINNAKER_SA_EMAIL --quiet
```
Delete the Cloud Pub/Sub topic and subscription:
```
export PROJECT_ID=$(gcloud info --format='value(config.project)')
gcloud pubsub topics delete projects/${PROJECT_ID}/topics/gcr
gcloud pubsub subscriptions delete gcr-triggers
```
Delete Cloud Storage buckets for the Spinnaker config files and Kubernetes manifests:
```
export PROJECT_ID=$(gcloud info --format='value(config.project)')
export BUCKET=${PROJECT_ID}-spinnaker-config
gsutil -m rm -r gs://${BUCKET}
gsutil -m rm -r gs://$PROJECT_ID-kubernetes-manifests
```
Delete sample-app from Cloud Source Repositories:
```
gcloud source repos delete sample-app --quiet
```
Delete container images from Container Registry:
```
gcloud container images delete gcr.io/${PROJECT_ID}/sample-app:v1.0.2 --force-delete-tags --quiet
gcloud container images delete gcr.io/${PROJECT_ID}/sample-app:v1.0.1 --force-delete-tags --quiet
gcloud container images delete gcr.io/${PROJECT_ID}/sample-app:v1.0.0 --force-delete-tags --quiet
```
Delete the WORKDIR folder:
```
cd ~
rm -rf $WORKDIR
```