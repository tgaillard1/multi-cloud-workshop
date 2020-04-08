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

Get workshop source code 
    ```shell
    git clone https://github.com/tgaillard1/multi-cloud-workshop.git
    cd ~/multi-cloud-workshop
    source ./env
    ```

### Create Spinnaker and Cluster

Set environment
    ```shell
    cd ~/multi-cloud-workshop
    source ./env
    ```

Copy Spinnaker application and create sim link
    ```shell
    mkdir $HOME/cloudshell_open
    ln -s $BASE_DIR/spinnaker-for-gcp $HOME/cloudshell_open/
    ```

Set Git credentials
```
git config --global user.email \
    "[GIT_EMAIL_ADDRESS]"
git config --global user.name \
    "[GIT_USERNAME]"
```

Set the Spinnaker variables
```
PROJECT_ID=$PROJECT_ID \
    ~/cloudshell_open/spinnaker-for-gcp/scripts/install/setup_properties.sh
```

Edit properties file for Istio
```
cat ~/cloudshell_open/spinnaker-for-gcp/scripts/install/properties | \
  sed -i 's/spinnaker-1/spinnaker1/g' ~/cloudshell_open/spinnaker-for-gcp/scripts/install/properties 
```

Run install for Spinnaker
```
~/cloudshell_open/spinnaker-for-gcp/scripts/install/setup.sh
```

Set new environment variables for Spinnaker
```
source ~/cloudshell_open/spinnaker-for-gcp/scripts/install/properties
```

Log into new cluster
```
gcloud container clusters get-credentials $GKE_CLUSTER --zone $ZONE --project ${PROJECT_ID}

Fetching cluster endpoint and auth data.
kubeconfig entry generated for spinnaker1
```

Log into Spinnaker UI
```
export DECK_POD=$(kubectl get pods --namespace spinnaker -l "cluster=spin-deck" \
    -o jsonpath="{.items[0].metadata.name}")
kubectl port-forward --namespace spinnaker $DECK_POD 9080:9000 >> /dev/null &
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

Restart Spinnaker Cluster -- labels
```
gcloud beta container clusters update $GKE_CLUSTER --identity-namespace=${IDNS} --zone $ZONE
gcloud beta container clusters update $GKE_CLUSTER --update-labels mesh_id=${MESH_ID} --zone $ZONE
```

Connect to clusters
```
gcloud container clusters get-credentials $GKE_CLUSTER --zone $ZONE --project ${PROJECT_ID}
gcloud container clusters get-credentials ${CLUSTER_NAME2} --zone ${CLUSTER_ZONE2} --project ${PROJECT_ID}
gcloud container clusters get-credentials ${CLUSTER_NAME3} --zone ${CLUSTER_ZONE3} --project ${PROJECT_ID}
```

Rename clusters
```
kubectx ${CLUSTER_NAME2}=gke_${PROJECT_ID}_${CLUSTER_ZONE2}_${CLUSTER_NAME2}
kubectx ${CLUSTER_NAME3}=gke_${PROJECT_ID}_${CLUSTER_ZONE3}_${CLUSTER_NAME3}
```

User Admin binding
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

Cluster Admin binding
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


Anthos Nomos Install
```
gsutil cp gs://config-management-release/released/latest/linux_amd64/nomos $WORKDIR/nomos
chmod +x $WORKDIR/nomos
sudo cp $WORKDIR/nomos /usr/local/bin/nomos
```

```
cd $WORKDIR
```

Install Kustomize
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
Proceed to --> **Create Input Variable for Config Management** below

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
cd ~/anthos-config-mgmt
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

----

Create Input Variable for Config Management
```
export REPO="config-mgmt-repo"
export ACCOUNT=YOUR_GIT_USER
export REPO_URL=https://github.com/${ACCOUNT}/${REPO}.git
```

Obtain and deploy operator for Spinnaker
```
gsutil cp gs://config-management-release/released/latest/config-management-operator.yaml $BASE_DIR/config-management-operator.yaml
```

Apply operator to clusters
```
kubectl apply -f $BASE_DIR/config-management-operator.yaml --context gke_${PROJECT_ID}_${ZONE}_${GKE_CLUSTER}
kubectl apply -f $BASE_DIR/config-management-operator.yaml --context ${CLUSTER_NAME2}
kubectl apply -f $BASE_DIR/config-management-operator.yaml --context ${CLUSTER_NAME3}
```

Create credentials for kubernetes
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

Spinnaker Cluster

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

## Adding Anthos Service Mesh 

```
curl --request POST \
--header "Authorization: Bearer $(gcloud auth print-access-token)" \
--data '' \
https://meshconfig.googleapis.com/v1alpha1/projects/${PROJECT_ID}:initialize
```

```
curl -Lo $WORKDIR/istio-1.4.6-asm.0-linux.tar.gz https://storage.googleapis.com/gke-release/asm/istio-1.4.6-asm.0-linux.tar.gz
```

```
curl -Lo $WORKDIR/istio-1.4.6-asm.0-linux.tar.gz.1.sig https://storage.googleapis.com/gke-release/asm/istio-1.4.6-asm.0-linux.tar.gz.1.sig
openssl dgst -verify - -signature $WORKDIR/istio-1.4.6-asm.0-linux.tar.gz.1.sig $WORKDIR/istio-1.4.6-asm.0-linux.tar.gz <<'EOF'
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEWZrGCUaJJr1H8a36sG4UUoXvlXvZ
wQfk16sxprI2gOJ2vFFggdq3ixF2h4qNBt0kI7ciDhgpwS8t+/960IsIgw==
-----END PUBLIC KEY-----
EOF
```

```
cd $WORKDIR/
```

```
tar xzf istio-1.4.6-asm.0-linux.tar.gz
```

```
cd $WORKDIR/istio-1.4.6-asm.0
```

```
export PATH=$PWD/bin:$PATH
```

```
istioctl manifest apply --set profile=asm \
  --set values.global.trustDomain=${IDNS} \
  --set values.global.sds.token.aud=${IDNS} \
  --set values.nodeagent.env.GKE_CLUSTER_URL="https://container.googleapis.com/v1/projects/${PROJECT_ID}/locations/${ZONE}/clusters/${GKE_CLUSTER}" \
  --set values.global.meshID=${MESH_ID} \
  --set values.global.proxy.env.GCP_METADATA="${PROJECT_ID}|${PROJECT_NUMBER}|${GKE_CLUSTER}|${ZONE}"
```

```
istioctl manifest apply --set profile=asm \
  --set values.global.trustDomain=${IDNS} \
  --set values.global.sds.token.aud=${IDNS} \
  --set values.nodeagent.env.GKE_CLUSTER_URL="https://container.googleapis.com/v1/projects/${PROJECT_ID}/locations/${CLUSTER_ZONE2}/clusters/${CLUSTER_NAME2}" \
  --set values.global.meshID=${MESH_ID} \
  --set values.global.proxy.env.GCP_METADATA="${PROJECT_ID}|${PROJECT_NUMBER}|${CLUSTER_NAME2}|${CLUSTER_ZONE2}"
```

```
  istioctl manifest apply --set profile=asm \
  --set values.global.trustDomain=${IDNS} \
  --set values.global.sds.token.aud=${IDNS} \
  --set values.nodeagent.env.GKE_CLUSTER_URL="https://container.googleapis.com/v1/projects/${PROJECT_ID}/locations/${CLUSTER_ZONE3}/clusters/${CLUSTER_NAME3}" \
  --set values.global.meshID=${MESH_ID} \
  --set values.global.proxy.env.GCP_METADATA="${PROJECT_ID}|${PROJECT_NUMBER}|${CLUSTER_NAME3}|${CLUSTER_ZONE3}"
```

```
kubectl wait --for=condition=available --timeout=600s deployment --all -n istio-system --context gke_${PROJECT_ID}_${ZONE}_${GKE_CLUSTER}
kubectl wait --for=condition=available --timeout=600s deployment --all -n istio-system --context=${CLUSTER_NAME2}
kubectl wait --for=condition=available --timeout=600s deployment --all -n istio-system --context=${CLUSTER_NAME3}
```

```
asmctl validate
asmctl validate --with-testing-workloads
```

```
kubectl label namespace default istio-injection=enabled --overwrite --context=gke_${PROJECT_ID}_${ZONE}_${GKE_CLUSTER}
kubectl label namespace default istio-injection=enabled --overwrite --context=${CLUSTER_NAME2}
kubectl label namespace default istio-injection=enabled --overwrite --context=${CLUSTER_NAME3}
```

```
kubectx ${CLUSTER_NAME2}
```

```
~/cloudshell_open/spinnaker-for-gcp/scripts/manage/add_gke_account.sh
```

Enter your currnt context (use default)
Enter your PROJECT_ID
Enter Spinnaker account name (use default)

```
kubectl config use-context gke_${PROJECT_ID}_${ZONE}_${GKE_CLUSTER}
```

```
~/cloudshell_open/spinnaker-for-gcp/scripts/manage/push_and_apply.sh
```

switch back to stage context and repeat

```
kubectx ${CLUSTER_NAME3}
```

```
~/cloudshell_open/spinnaker-for-gcp/scripts/manage/add_gke_account.sh
```

Enter your currnt context (use default)
Enter your PROJECT_ID
Enter Spinnaker account name (use default)

```
kubectl config use-context gke_${PROJECT_ID}_${ZONE}_${GKE_CLUSTER}
```

```
~/cloudshell_open/spinnaker-for-gcp/scripts/manage/push_and_apply.sh
```


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


Can use downloaded Ford Sample App $BASE_DIR/continuous-integration-on-kubernetes/sample-app
++++++++++++

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

```
git init
git add .
git commit -m "Initial commit"
```

```
gcloud source repos create sample-app
```

```
git remote add origin https://source.developers.google.com/p/$PROJECT_ID/r/sample-app
git push origin master
```

**********************
Option Change to GIT Credentials
```
git config --global user.email \
    "[EMAIL_ADDRESS]"
git config --global user.name \
    "[USERNAME]"
```

Make the initial commit to your source code repository:
```
git init
git add .
git commit -m "Initial commit-4-3-20"
```


Add your new repository as remote, and push your code to the master branch of the remote repository:

**********************


View Source code

```
https://console.cloud.google.com/code/develop/browse/sample-app/master?_ga=2.22785213.-768538728.1545413763
```
++++++++++++


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
```


Verify build is pushed by going to Cloud Build --> History



### Create a multi-cluster deployment pipeline

Use spin to create an application in Spinnaker:

Install Spin
```
curl -Lo $WORKDIR/spin https://storage.googleapis.com/spinnaker-artifacts/spin/1.5.2/linux/amd64/spin
chmod +x $WORKDIR/spin
sudo cp $WORKDIR/spin /usr/local/bin/spin
```

```
cd $WORKDIR
./spin application save --application-name sample2 \
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
git tag v1.0.4
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
