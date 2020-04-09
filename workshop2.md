## Workshop 2 -- CD Spinnaker

![Workshop 1 Screenshot](images/workshop2-arch-diagram.png?raw=true "Workshop 2 Diagram")

## Prerequisites
*  A Google Cloud Platform Account
*  A Git Hub Account
*  Set Project
```
gcloud config set project REPLACE_WITH_YOUR_PROJECT_ID 
```

*  Enable API's
    ```shell
    gcloud services enable \
        container.googleapis.com \
        compute.googleapis.com \
        stackdriver.googleapis.com \
        meshca.googleapis.com \
        meshtelemetry.googleapis.com \
        meshconfig.googleapis.com \
        iamcredentials.googleapis.com \
        sourcerepo.googleapis.com \
        redis.googleapis.com \
        anthos.googleapis.com
    ```

**NOTE** -- Skip the next step if you have already download the source code from the first workshop (1).

*  Get workshop source code
    ```shell
    git clone https://github.com/tgaillard1/multi-cloud-workshop.git
    cd ~/multi-cloud-workshop
    source ./env
    ```

### Create Spinnaker and Cluster

*  Set environment
    ```shell
    cd ~/multi-cloud-workshop
    source ./env
    ```

*  Copy Spinnaker application and create sim link
    ```shell
    mkdir $HOME/cloudshell_open
    ln -s $BASE_DIR/spinnaker-for-gcp $HOME/cloudshell_open/
    ```

*  Set Git credentials
    ```shell
    git config --global user.email \
        "[GIT_EMAIL_ADDRESS]"
    git config --global user.name \
        "[GIT_USERNAME]"
    ```

*  Set the Spinnaker variables
    ```shell
    PROJECT_ID=$PROJECT_ID \
        ~/cloudshell_open/spinnaker-for-gcp/scripts/install/setup_properties.sh
    ```

*  Edit properties file for Istio
    ```shell
    cat ~/cloudshell_open/spinnaker-for-gcp/scripts/install/properties | \
    sed -i 's/spinnaker-1/spinnaker1/g' ~/cloudshell_open/spinnaker-for-gcp/scripts/install/properties 
    ```

*  Run install for Spinnaker
```
~/cloudshell_open/spinnaker-for-gcp/scripts/install/setup.sh
```

*  Set new environment variables for Spinnaker
```
source ~/cloudshell_open/spinnaker-for-gcp/scripts/install/properties
```

*  Log into new cluster
```
gcloud container clusters get-credentials $GKE_CLUSTER --zone $ZONE --project ${PROJECT_ID}

Fetching cluster endpoint and auth data.
kubeconfig entry generated for spinnaker1
```

*  Log into Spinnaker UI
```
export DECK_POD=$(kubectl get pods --namespace spinnaker -l "cluster=spin-deck" \
    -o jsonpath="{.items[0].metadata.name}")
kubectl port-forward --namespace spinnaker $DECK_POD 8080:9000 >> /dev/null &
```

### Set up deployment clusters

```
gcloud beta container clusters create ${CLUSTER_NAME2} \
    --machine-type=${NODE_SIZE} \
    --num-nodes=${NODE_COUNT} \
    --identity-namespace=${IDNS} \
    --enable-stackdriver-kubernetes \
    --subnetwork=default \
    --labels mesh_id=${MESH_ID} \
    --zone ${CLUSTER_ZONE2} \
    --scopes "https://www.googleapis.com/auth/source.read_write,cloud-platform"

gcloud beta container clusters create ${CLUSTER_NAME3} \
    --machine-type=${NODE_SIZE} \
    --num-nodes=${NODE_COUNT} \
    --identity-namespace=${IDNS} \
    --enable-stackdriver-kubernetes \
    --subnetwork=default \
    --labels mesh_id=${MESH_ID} \
    --zone ${CLUSTER_ZONE3} \
    --scopes "https://www.googleapis.com/auth/source.read_write,cloud-platform"

```

*  Restart Spinnaker Cluster -- labels
```
gcloud beta container clusters update $GKE_CLUSTER --identity-namespace=${IDNS} --zone $ZONE
gcloud beta container clusters update $GKE_CLUSTER --update-labels mesh_id=${MESH_ID} --zone $ZONE
```

*  Connect to clusters
```
gcloud container clusters get-credentials $GKE_CLUSTER --zone $ZONE --project ${PROJECT_ID}
gcloud container clusters get-credentials ${CLUSTER_NAME2} --zone ${CLUSTER_ZONE2} --project ${PROJECT_ID}
gcloud container clusters get-credentials ${CLUSTER_NAME3} --zone ${CLUSTER_ZONE3} --project ${PROJECT_ID}
```

*  Rename clusters
```
kubectx ${CLUSTER_NAME2}=gke_${PROJECT_ID}_${CLUSTER_ZONE2}_${CLUSTER_NAME2}
kubectx ${CLUSTER_NAME3}=gke_${PROJECT_ID}_${CLUSTER_ZONE3}_${CLUSTER_NAME3}
```

*  User Admin binding
```
kubectl create clusterrolebinding user-admin-binding \
    --clusterrole=cluster-admin \
    --user=$(gcloud config get-value account) \
    --context gke_${PROJECT_ID}_${ZONE}_${GKE_CLUSTER}

kubectl create clusterrolebinding user-admin-binding \
    --clusterrole=cluster-admin \
    --user=$(gcloud config get-value account) \
    --context ${CLUSTER_NAME2}

kubectl create clusterrolebinding user-admin-binding \
    --clusterrole=cluster-admin \
    --user=$(gcloud config get-value account) \
    --context ${CLUSTER_NAME3}
```

*  Cluster Admin binding
```
kubectl create clusterrolebinding cluster-admin-binding \
  --clusterrole cluster-admin \
  --user=$(gcloud config get-value account) \
  --context gke_${PROJECT_ID}_${ZONE}_${GKE_CLUSTER}

kubectl create clusterrolebinding cluster-admin-binding \
  --clusterrole cluster-admin \
  --user=$(gcloud config get-value account) \
    --context ${CLUSTER_NAME2}

kubectl create clusterrolebinding cluster-admin-binding \
  --clusterrole cluster-admin \
  --user=$(gcloud config get-value account) \
    --context ${CLUSTER_NAME3}
```

## Adding Config Management


*  Anthos Nomos Install
```
gsutil cp gs://config-management-release/released/latest/linux_amd64/nomos $WORKDIR/nomos
chmod +x $WORKDIR/nomos
sudo cp $WORKDIR/nomos /usr/local/bin/nomos
```

```
cd $WORKDIR
```

*  Install Kustomize
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

## Note -- Skip this step if you have completed it in workshop (1,3)
Proceed to --> **Git Hub Configured -- Add Variables and Credentials** below

### Create Git Hub Config Management Repo

*  Create Git Hub Repo
Login to your Git Hub account --> got to repositories --> select "New" --> Enter variables below:
+ Repository Name = config-mgmt-repo
+ Description = Config Management for multi-cloud
+ --> Creat Repository

Copy Repo URL link and enter below

*  Create Input Variable for Config Management
```
export REPO="config-mgmt-repo"
export ACCOUNT=YOUR_GIT_USER
export REPO_URL=https://github.com/${ACCOUNT}/${REPO}.git
```

*  Initialize for Git Push
```
cd $HOME
cp -rf $BASE_DIR/config-mgmt-repo/ .
cd ~/anthos-config-mgmt
git init
git config credential.helper
git remote add origin $REPO_URL
```

*  Push Files to Git Repo
```
git add .
git commit -m "Initial commit"
git push origin master
```

*  Add deployment key to GIT repo
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

----

### Git Hub Configured -- Add Variables and Credentials

*  Add Variables
```
export REPO="config-mgmt-repo"
export ACCOUNT=YOUR_GIT_USER
export REPO_URL=https://github.com/${ACCOUNT}/${REPO}.git
```

*  Obtain and deploy operator for Spinnaker
```
gsutil cp gs://config-management-release/released/latest/config-management-operator.yaml $BASE_DIR/config-management-operator.yaml
```

*  Apply operator to clusters
```
kubectl apply -f $BASE_DIR/config-management-operator.yaml --context gke_${PROJECT_ID}_${ZONE}_${GKE_CLUSTER}
kubectl apply -f $BASE_DIR/config-management-operator.yaml --context ${CLUSTER_NAME2}
kubectl apply -f $BASE_DIR/config-management-operator.yaml --context ${CLUSTER_NAME3}
```

*  Create credentials for kubernetes
```
kubectl create secret generic git-creds \
--namespace=config-management-system \
--context=gke_${PROJECT_ID}_${ZONE}_${GKE_CLUSTER} \
--from-file=ssh=${HOME}/.ssh/anthos-demo-key
```

```
kubectl create secret generic git-creds \
--namespace=config-management-system \
--context=${CLUSTER_NAME2} \
--from-file=ssh=${HOME}/.ssh/anthos-demo-key
```

```
kubectl create secret generic git-creds \
--namespace=config-management-system \
--context=${CLUSTER_NAME3} \
--from-file=ssh=${HOME}/.ssh/anthos-demo-key
```

### Create Config Management for Kubernetes

*  Spinnaker Cluster

```
kubectx gke_${PROJECT_ID}_${ZONE}_${GKE_CLUSTER}
```

```
cat > $BASE_DIR/config-management-${GKE_CLUSTER}.yaml <<EOF
apiVersion: configmanagement.gke.io/v1
kind: ConfigManagement
metadata:
  name: config-management
spec:
  # clusterName is required and must be unique among all managed clusters
  clusterName: ${GKE_CLUSTER}
  git:
    syncRepo: git@github.com:tgaillard1/anthos-demo.git
    syncBranch: master
    secretType: ssh
    policyDir: "."
EOF
```

```
kubectl apply -f $BASE_DIR/config-management-${GKE_CLUSTER}.yaml --context=gke_${PROJECT_ID}_${ZONE}_${GKE_CLUSTER}
```

```
nomos status to validate | grep ${GKE_CLUSTER} --> SYNCED
```

Dev Cluster
```
kubectx ${CLUSTER_NAME2}
```

```
cat > $BASE_DIR/config-management-${CLUSTER_NAME2}.yaml <<EOF
apiVersion: configmanagement.gke.io/v1
kind: ConfigManagement
metadata:
  name: config-management
spec:
  # clusterName is required and must be unique among all managed clusters
  clusterName: ${CLUSTER_NAME2}
  git:
    syncRepo: git@github.com:tgaillard1/anthos-demo.git
    syncBranch: master
    secretType: ssh
    policyDir: "."
EOF
```

```
kubectl apply -f $BASE_DIR/config-management-${CLUSTER_NAME2}.yaml --context=${CLUSTER_NAME2}
```

```
nomos status to validate | grep ${CLUSTER_NAME2} --> SYNCED
```

Stage Cluster

```
kubectx ${CLUSTER_NAME3}
```

```
cat > $BASE_DIR/config-management-${CLUSTER_NAME3}.yaml <<EOF
apiVersion: configmanagement.gke.io/v1
kind: ConfigManagement
metadata:
  name: config-management
spec:
  # clusterName is required and must be unique among all managed clusters
  clusterName: ${CLUSTER_NAME3}
  git:
    syncRepo: git@github.com:tgaillard1/anthos-demo.git
    syncBranch: master
    secretType: ssh
    policyDir: "."
EOF
```

```
kubectl apply -f $BASE_DIR/config-management-${CLUSTER_NAME3}.yaml --context=${CLUSTER_NAME3}
```

```
nomos status to validate | grep ${CLUSTER_NAME3} --> SYNCED
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

Initiate install of asm for Spinnaker cluster
```
istioctl manifest apply --set profile=asm \
  --set values.global.trustDomain=${IDNS} \
  --set values.global.sds.token.aud=${IDNS} \
  --set values.nodeagent.env.GKE_CLUSTER_URL="https://container.googleapis.com/v1/projects/${PROJECT_ID}/locations/${ZONE}/clusters/${GKE_CLUSTER}" \
  --set values.global.meshID=${MESH_ID} \
  --set values.global.proxy.env.GCP_METADATA="${PROJECT_ID}|${PROJECT_NUMBER}|${GKE_CLUSTER}|${ZONE}"
```

Validate Install
```
kubectl wait --for=condition=available --timeout=600s deployment --all -n istio-system --context gke_${PROJECT_ID}_${ZONE}_${GKE_CLUSTER}
kubectl wait --for=condition=available --timeout=600s deployment --all -n istio-system --context=${CLUSTER_NAME2}
```
*  This should return:

   **deployment.extensions/istio-galley condition met**
   **deployment.extensions/istio-ingressgateway condition met**
   **deployment.extensions/istio-pilot condition met**
   **deployment.extensions/istio-sidecar-injector condition met**
   **deployment.extensions/promsd condition met**


Initiate install of asm for Dev cluster
```
 istioctl manifest apply --set profile=asm \
  --set values.global.trustDomain=${IDNS} \
  --set values.global.sds.token.aud=${IDNS} \
  --set values.nodeagent.env.GKE_CLUSTER_URL="https://container.googleapis.com/v1/projects/${PROJECT_ID}/locations/${CLUSTER_ZONE2}/clusters/${CLUSTER_NAME2}" \
  --set values.global.meshID=${MESH_ID} \
  --set values.global.proxy.env.GCP_METADATA="${PROJECT_ID}|${PROJECT_NUMBER}|${CLUSTER_NAME2}|${CLUSTER_ZONE2}"
```

Validate Install
```
kubectl wait --for=condition=available --timeout=600s deployment --all -n istio-system --context=${CLUSTER_NAME2}
```

Initiate install of asm for Stage cluster
```
  istioctl manifest apply --set profile=asm \
  --set values.global.trustDomain=${IDNS} \
  --set values.global.sds.token.aud=${IDNS} \
  --set values.nodeagent.env.GKE_CLUSTER_URL="https://container.googleapis.com/v1/projects/${PROJECT_ID}/locations/${CLUSTER_ZONE3}/clusters/${CLUSTER_NAME3}" \
  --set values.global.meshID=${MESH_ID} \
  --set values.global.proxy.env.GCP_METADATA="${PROJECT_ID}|${PROJECT_NUMBER}|${CLUSTER_NAME3}|${CLUSTER_ZONE3}"
```

Validate Install
```
kubectl wait --for=condition=available --timeout=600s deployment --all -n istio-system --context=${CLUSTER_NAME3}
```

Change labels to ensure Istio/Envoy is deployed as sidecar
```
kubectl label namespace default istio-injection=enabled --overwrite --context=gke_${PROJECT_ID}_${ZONE}_${GKE_CLUSTER}
kubectl label namespace default istio-injection=enabled --overwrite --context=${CLUSTER_NAME2}
kubectl label namespace default istio-injection=enabled --overwrite --context=${CLUSTER_NAME3}
```

## Add clusters to Spinnaker for deployments

Add Dev cluster
```
kubectx ${CLUSTER_NAME2}

~/cloudshell_open/spinnaker-for-gcp/scripts/manage/add_gke_account.sh
```

Enter your currnt context (use default)
Enter your PROJECT_ID
Enter Spinnaker account name (use default)

Change context to Spinnaker cluster and add Dev
```
kubectl config use-context gke_${PROJECT_ID}_${ZONE}_${GKE_CLUSTER}

~/cloudshell_open/spinnaker-for-gcp/scripts/manage/push_and_apply.sh
```

Add Stage cluster

```
kubectx ${CLUSTER_NAME3}

~/cloudshell_open/spinnaker-for-gcp/scripts/manage/add_gke_account.sh
```

Enter your currnt context (use default)
Enter your PROJECT_ID
Enter Spinnaker account name (use default)

Change context to Spinnaker cluster and add Stage
```
kubectl config use-context gke_${PROJECT_ID}_${ZONE}_${GKE_CLUSTER}

~/cloudshell_open/spinnaker-for-gcp/scripts/manage/push_and_apply.sh
```

*  Log into Spinnaker UI
```
export DECK_POD=$(kubectl get pods --namespace spinnaker -l "cluster=spin-deck" \
    -o jsonpath="{.items[0].metadata.name}")
kubectl port-forward --namespace spinnaker $DECK_POD 8080:9000 >> /dev/null &
```

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

## Install AWS Managed account --- TBD

Install AWS CLI

```
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

```
/usr/local/bin/aws --version
```

ADD AWS -- https://www.spinnaker.io/setup/install/providers/kubernetes-v2/aws-eks/

```
curl -O https://d3079gxvs8ayeg.cloudfront.net/templates/managed.yaml  
```

```
aws cloudformation deploy --stack-name spinnaker-managed-infrastructure-setup --template-file managed.yaml \
--parameter-overrides AuthArn=$AUTH_ARN ManagingAccountId=$MANAGING_ACCOUNT_ID --capabilities CAPABILITY_NAMED_IAM
```

@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

# Install and run sample application and pipelines

## Introduction

* A sample "hello world" Go application
* A Cloud Build trigger to build an image from source
* Sample Spinnaker pipelines to deploy the image and validate the application in a progression from staging environment to production

To proceed, make sure the Spinnaker instance is reachable with port-forwarding or is exposed publicly.

$BASE_DIR/multi-cloud-workshop/spinnaker-for-gcp/scripts/manage/connect_unsecured.sh

Select the project containing your Spinnaker instance, then click **Start**, below.

## Create application and pipelines

Run this command to create the required resources:

```
~/cloudshell_open/spinnaker-for-gcp/samples/helloworldwebapp/create_app_and_pipelines.sh
```

### Resources created:

The source code is hosted in a repository in [Cloud Source Repository](https://source.cloud.google.com/{{project-id}}/spinnaker-for-gcp-helloworldwebapp)
in the same project as your Spinnaker cluster.

This repository contains a few other items:

* Kubernetes configs for the application

  These are used to deploy the application and validate the service.

* A [Cloud Build config](https://source.cloud.google.com/{{project-id}}/spinnaker-for-gcp-helloworldwebapp/+/master:cloudbuild.yaml)

  This builds the image and copies the Kubernetes configs to the Spinnaker GCS bucket.

* A [Cloud Build trigger](https://console.developers.google.com/cloud-build/triggers?project={{project-id}}) 

  This executes the Cloud Build config when any source code or manifest files are changed under
  src/** or config/** in the repository.

Cloud Build creates an [image](https://gcr.io/{{project-id}}/spinnaker-for-gcp-helloworldwebapp)
from source and tags that image with the short commit hash.

The script also creates two Kubernetes namespaces...
* **helloworldwebapp-staging**
* **helloworldwebapp-prod**

...and the **helloworldwebapp-service** service in each of those namespaces, in the [Spinnaker Kubernetes cluster](https://console.developers.google.com/kubernetes/discovery?project={{project-id}}).

These services expose the Go application for staging and prod environments.

This process creates two Spinnaker pipelines under the **helloworldwebapp** Spinnaker application:

* **Deploy to Staging**

  This triggers on a newly completed GCB build, and deploys the image to the
  **helloworldwebapp-staging** namespace. It then runs a validation job to check the health status of the service.

* **Deploy to Production**

  This starts on a successful **Deploy to Staging** run and Blue/Green deploys 
  the tested image to **helloworldwebapp-prod** namespace. It then runs the health validation job.
 
  On success, the old replicaset is scaled down after a 5 minute wait period.

  On failure, the old replicaset is re-enabled and the new replicaset is disabled. A Pub/Sub
  notification of the failure is sent via the preconfigured Pub/Sub publisher.

You can navigate to your Spinnaker UI to see these pipelines.

## Start a new build

To build and deploy an image, just change some [source code](https://source.cloud.google.com/{{project-id}}/spinnaker-for-gcp-helloworldwebapp/+/master:src/main.go)
or [manifest files](https://source.cloud.google.com/{{project-id}}/spinnaker-for-gcp-helloworldwebapp/+/master:config/) and push the change to the master branch. 

The repository is already cloned to your home directory. Make some changes to the source code...

```bash
cloudshell edit ~/{{project-id}}/spinnaker-for-gcp-helloworldwebapp/src/main.go
```

...and commit the changes:
```bash
cd ~/{{project-id}}/spinnaker-for-gcp-helloworldwebapp

git commit -am "Cool new features"
git push
```

The new commit triggers the chain of events...
1. Cloud Build builds the image.
2. The **Deploy to Staging** pipeline deploys the image to staging and validates it.
3. The **Deploy to Production** pipeline promotes the image to production and validates it.

Visit the Spinnaker UI to verify that the pipelines complete successfully.

After the pipelines finish, the [**helloworldwebapp-services**](https://console.developers.google.com/kubernetes/discovery?project={{project-id}})
hosting the Go application will now be up and healthy. Click on the **endpoints**
for each service to see a "Hello World" page!

### Clean-up

Run this command to delete all the resources created above:

```bash
~/cloudshell_open/spinnaker-for-gcp/samples/helloworldwebapp/cleanup_app_and_pipelines.sh && cd ~/cloudshell_open/spinnaker-for-gcp
```

### Return to Spinnaker console

Run this command to return to the management environment:

```bash
~/cloudshell_open/spinnaker-for-gcp/scripts/manage/update_console.sh
```

