


******************************************************
## Workshop 2 -- CD Spinnaker


### Prerequisites
------
1. A Google Cloud Platform Account
1. [Enable the Cloud Build and Cloud Source Repositories APIs](https://console.cloud.google.com/flows/enableapi?apiid=container,cloudbuild.googleapis.com,sourcerepo.googleapis.com&redirect=https://console.cloud.google.com&_ga=2.48886959.843635228.1580750081-768538728.1545413763)

Set Project and Zone
```
gcloud config set project REPLACE_WITH_YOUR_PROJECT_ID 
gcloud config set compute/zone YOUR_ZONE
```

Create Spinnaker Home
```
source ./env

cd $SPINNAKER_DIR
```

HELM_VERSION=v2.14.1
HELM_PATH="$WORKDIR"/helm-"$HELM_VERSION"
wget https://storage.googleapis.com/kubernetes-helm/helm-"$HELM_VERSION"-linux-amd64.tar.gz
tar -xvzf helm-"$HELM_VERSION"-linux-amd64.tar.gz
mv linux-amd64 "$HELM_PATH"

gcloud container clusters create spinnaker --zone us-west2-a \
    --num-nodes 4 --machine-type n1-standard-2 --async
gcloud container clusters create west --zone us-west2-b \
    --num-nodes 3 --machine-type n1-standard-2 --async
gcloud container clusters create east --zone us-east4-a \
    --num-nodes 3 --machine-type n1-standard-2

&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&

export PROJECT_ID=$(gcloud config list --format 'value(core.project)' 2>/dev/null)
export PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format="value(projectNumber)")
export CLUSTER_NAME1=spinnaker
export CLUSTER_NAME2=west
export CLUSTER_NAME3=east
export CLUSTER_ZONE1=us-central1-a
export CLUSTER_ZONE2=us-west2-b
export CLUSTER_ZONE3=us-east4-a
export IDNS=${PROJECT_ID}.svc.id.goog
export MESH_ID="proj-${PROJECT_NUMBER}"


gcloud container clusters create spinnaker --zone us-west2-a \
    --num-nodes 3 --machine-type n1-standard-2 --async

gcloud container clusters create west --zone us-west2-b \
    --num-nodes 3 --machine-type n1-standard-2 --async

gcloud container clusters create east --zone us-east4-a \
    --num-nodes 3 --machine-type n1-standard-2





&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&





### Install Helm -- **NOTE --- Skip this step if you have already completed it in Workshop 1**
------
```
wget https://storage.googleapis.com/kubernetes-helm/helm-$HELM_VERSION-linux-amd64.tar.gz -P $WORKDIR/
tar -xvzf $WORKDIR/helm-$HELM_VERSION-linux-amd64.tar.gz -C $WORKDIR/ 
mv $WORKDIR/linux-amd64 $HELM_PATH
```

Install kubectx and kubens
```
git clone https://github.com/ahmetb/kubectx $WORKDIR/kubectx
export PATH=$PATH:$WORKDIR/kubectx
```

Install Spin
```
curl -Lo $WORKDIR/spin https://storage.googleapis.com/spinnaker-artifacts/spin/1.5.2/linux/amd64/spin
chmod +x $WORKDIR/spin
```

Create GKE clusters
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


#Validate they are running

gcloud container clusters list
```

Connect to all three clusters 
```
gcloud container clusters get-credentials ${CLUSTER_NAME1} --zone ${CLUSTER_ZONE1} --project ${PROJECT_ID}

gcloud container clusters get-credentials spinnaker-1 --zone us-east1-c --project ${PROJECT_ID}
gcloud container clusters get-credentials ${CLUSTER_NAME2} --zone ${CLUSTER_ZONE2} --project ${PROJECT_ID}
gcloud container clusters get-credentials ${CLUSTER_NAME3} --zone ${CLUSTER_ZONE3} --project ${PROJECT_ID}
```

#Rename clusters

kubectx ${CLUSTER_NAME1}=gke_${PROJECT_ID}_${CLUSTER_ZONE1}_${CLUSTER_NAME1}
kubectx ${CLUSTER_NAME2}=gke_${PROJECT_ID}_${CLUSTER_ZONE2}_${CLUSTER_NAME2}
kubectx ${CLUSTER_NAME3}=gke_${PROJECT_ID}_${CLUSTER_ZONE3}_${CLUSTER_NAME3}


```

Set permissions for cluster-admin
```
kubectl create clusterrolebinding user-admin-binding \
    --clusterrole=cluster-admin \
    --user=$(gcloud config get-value account) \
    --context ${CLUSTER_NAME1}
kubectl create clusterrolebinding user-admin-binding \
    --clusterrole=cluster-admin \
    --user=$(gcloud config get-value account) \
    --context ${CLUSTER_NAME2}
kubectl create clusterrolebinding user-admin-binding \
    --clusterrole=cluster-admin \
    --user=$(gcloud config get-value account) \
    --context ${CLUSTER_NAME3}
```



&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&

```
curl --request POST \
  --header "Authorization: Bearer $(gcloud auth print-access-token)" \
  --data '' \
  https://meshconfig.googleapis.com/v1alpha1/projects/${PROJECT_ID}:initialize
```

Download the Anthos Service Mesh installation file to your current working directory:

curl -Lo $WORKDIR/istio-1.4.6-asm.0-linux.tar.gz https://storage.googleapis.com/gke-release/asm/istio-1.4.6-asm.0-linux.tar.gz


curl -LO https://storage.googleapis.com/gke-release/asm/istio-1.4.6-asm.0-linux.tar.gz.1.sig
openssl dgst -verify - -signature istio-1.4.6-asm.0-linux.tar.gz.1.sig istio-1.4.6-asm.0-linux.tar.gz <<'EOF'
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEWZrGCUaJJr1H8a36sG4UUoXvlXvZ
wQfk16sxprI2gOJ2vFFggdq3ixF2h4qNBt0kI7ciDhgpwS8t+/960IsIgw==
-----END PUBLIC KEY-----
EOF


tar xzf $WORKDIR/istio-1.4.6-asm.0-linux.tar.gz -C $WORKDIR/

export PATH=$WORKDIR/istio-1.4.6-asm.0/bin:$PATH


istioctl manifest apply --set profile=asm \
  --context ${CLUSTER_NAME1} \
  --set values.global.trustDomain=${IDNS} \
  --set values.global.sds.token.aud=${IDNS} \
  --set values.nodeagent.env.GKE_CLUSTER_URL=https://container.googleapis.com/v1/projects/${PROJECT_ID}/locations/${CLUSTER_ZONE1}/clusters/${CLUSTER_NAME1} \
  --set values.global.meshID=${MESH_ID} \
  --set values.global.proxy.env.GCP_METADATA="${PROJECT_ID}|${PROJECT_NUMBER}|${CLUSTER_NAME1}|${CLUSTER_ZONE1}"

istioctl manifest apply --set profile=asm \
  --context ${CLUSTER_NAME2} \
  --set values.global.trustDomain=${IDNS} \
  --set values.global.sds.token.aud=${IDNS} \
  --set values.nodeagent.env.GKE_CLUSTER_URL=https://container.googleapis.com/v1/projects/${PROJECT_ID}/locations/${CLUSTER_ZONE2}/clusters/${CLUSTER_NAME2} \
  --set values.global.meshID=${MESH_ID} \
  --set values.global.proxy.env.GCP_METADATA="${PROJECT_ID}|${PROJECT_NUMBER}|${CLUSTER_NAME2}|${CLUSTER_ZONE2}"

istioctl manifest apply --set profile=asm \
  --context ${CLUSTER_NAME3} \
  --set values.global.trustDomain=${IDNS} \
  --set values.global.sds.token.aud=${IDNS} \
  --set values.nodeagent.env.GKE_CLUSTER_URL=https://container.googleapis.com/v1/projects/${PROJECT_ID}/locations/${CLUSTER_ZONE3}/clusters/${CLUSTER_NAME3} \
  --set values.global.meshID=${MESH_ID} \
  --set values.global.proxy.env.GCP_METADATA="${PROJECT_ID}|${PROJECT_NUMBER}|${CLUSTER_NAME3}|${CLUSTER_ZONE3}"

kubectl wait --for=condition=available --timeout=600s deployment --all -n istio-system --context ${CLUSTER_NAME1}
kubectl wait --for=condition=available --timeout=600s deployment --all -n istio-system --context ${CLUSTER_NAME2}
kubectl wait --for=condition=available --timeout=600s deployment --all -n istio-system --context ${CLUSTER_NAME3}

asmctl validate --context ${CLUSTER_NAME1}
asmctl validate --with-testing-workloads --context ${CLUSTER_NAME1}

kubectl label namespace default istio-injection=enabled --overwrite --context ${CLUSTER_NAME1}
kubectl label namespace default istio-injection=enabled --overwrite --context ${CLUSTER_NAME2}
kubectl label namespace default istio-injection=enabled --overwrite --context ${CLUSTER_NAME3}



&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&


Create Service Account
```
gcloud iam service-accounts create ${CLUSTER_NAME1} --display-name ${CLUSTER_NAME1}-service-account

SPINNAKER_SA_EMAIL=$(gcloud iam service-accounts list \
    --filter="displayName:${CLUSTER_NAME1}-service-account" \
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
gcloud iam service-accounts keys create $WORKDIR/${CLUSTER_NAME1}-service-account.json --iam-account ${SPINNAKER_SA_EMAIL}
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


kubectl label namespace kube-system istio-injection=enabled --overwrite



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
export SA_JSON=$(cat $WORKDIR/${CLUSTER_NAME1}-service-account.json)
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
${HELM_PATH}/helm install -n spin stable/spinnaker -f spinnaker-config.yaml --timeout 600 --version 1.8.1 --wait --debug
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
kubectl --context ${CLUSTER_NAME2} apply -f spinnaker-sa.yaml
kubectl --context ${CLUSTER_NAME3} apply -f spinnaker-sa.yaml
```

Get the CLUSTER_NAME2 and CLUSTER_NAME3 cluster names, and the Kubernetes service account:

```
DEV_CLUSTER=gke_${PROJECT_ID}_${CLUSTER_ZONE2}_${CLUSTER_NAME2}
STAGE_CLUSTER=gke_${PROJECT_ID}_${CLUSTER_ZONE3}_${CLUSTER_NAME3}
DEV_USER=${CLUSTER_NAME2}-spinnaker-service-account
STAGE_USER=${CLUSTER_NAME3}-spinnaker-service-account
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

Validate deployments
----------------



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
git commit -m "Initial commit-1-5-20"
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