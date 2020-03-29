

git clone https://github.com/GoogleCloudPlatform/spinnaker-for-gcp.git

git config --global user.email \
    "timlgaillard@gmail.com"
git config --global user.name \
    "tgaillard1"

git config --global user.email \
    "[EMAIL_ADDRESS]"
git config --global user.name \
    "[USERNAME]"

PROJECT_ID=tgproject1-221717 \
    ~/testme/spinnaker-for-gcp/scripts/install/setup_properties.sh


~/testme/spinnaker-for-gcp/scripts/install/setup.sh

gcloud container clusters get-credentials spinnaker-2 --zone us-east1-c --project ${PROJECT_ID}

export DECK_POD=$(kubectl get pods --namespace spinnaker -l "cluster=spin-deck" \
    -o jsonpath="{.items[0].metadata.name}")
kubectl port-forward --namespace spinnaker $DECK_POD 9080:9000 >> /dev/null &


Set up additonal clusters

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

Connect to clusters
```
gcloud container clusters get-credentials ${CLUSTER_NAME2} --zone ${CLUSTER_ZONE2} --project ${PROJECT_ID}
gcloud container clusters get-credentials ${CLUSTER_NAME3} --zone ${CLUSTER_ZONE3} --project ${PROJECT_ID}
```

#Rename clusters
kubectx ${CLUSTER_NAME2}=gke_${PROJECT_ID}_${CLUSTER_ZONE2}_${CLUSTER_NAME2}
kubectx ${CLUSTER_NAME3}=gke_${PROJECT_ID}_${CLUSTER_ZONE3}_${CLUSTER_NAME3}


kubectl create clusterrolebinding user-admin-binding \
    --clusterrole=cluster-admin \
    --user=$(gcloud config get-value account) \
    --context ${CLUSTER_NAME2}
kubectl create clusterrolebinding user-admin-binding \
    --clusterrole=cluster-admin \
    --user=$(gcloud config get-value account) \
    --context ${CLUSTER_NAME3}


*********************************************************************
*********************************************************************

Adding Config Management
https://github.com/GoogleCloudPlatform/gke-anthos-holistic-demo/tree/master/anthos

*********************************************************************
*********************************************************************

------------
Anthos Nomos Install
gsutil cp gs://config-management-release/released/latest/linux_amd64/nomos $WORKDIR/nomos
chmod +x $WORKDIR/nomos
sudo cp $WORKDIR/nomos /usr/local/bin/nomos

opsys=linux
curl -s https://api.github.com/repos/kubernetes-sigs/kustomize/releases/latest |\
  grep browser_download |\
  grep $opsys |\
  cut -d '"' -f 4 |\
  xargs curl -L -o kustomize

sudo chmod +x kustomize
sudo cp kustomize /usr/local/bin/kustomize


REPO="anthos-demo"
PROJECT=$(gcloud config list --format 'value(core.project)' 2>/dev/null)
ACCOUNT=$(gcloud config list --format 'value(core.account)' 2>/dev/null)

cp -rf ~/multi-cloud-workshop/anthos-config-mgmt/ .
cd anthos-config-mgmt/
git clone https://github.com/tgaillard1/anthos-demo.git
nomos init
ls -lrt
cd anthos-demo/
nomos init

git add .
git commit -m 'Adding initial files for nomos'
git push origin master

kubectx (to verify cluster)

kubectl create clusterrolebinding cluster-admin-binding \
  --clusterrole cluster-admin \
  --user="$(gcloud config get-value core/account)"


gsutil cp gs://config-management-release/released/latest/config-management-operator.yaml config-management-operator.yaml

kubectl apply -f config-management-operator.yaml

Demo uses the altostrat GSR account -- this is for GIT

ssh-keygen -t rsa -b 4096 \
 -C "tgaillard1" \
 -N '' \
 -f /home/tgaillard/.ssh/anthos-demo-key

---------------------
Add deployment key to GIT repo
Go to Git -- Repo --> anthos-demo --> settings --> Deploy keys --> Add deploy key


cat /home/tgaillard/.ssh/anthos-demo-key.pub

copy contents and add with --> Allow write access
---------------------

kubectl create secret generic git-creds \
--namespace=config-management-system \
--from-file=ssh=/home/tgaillard/.ssh/anthos-demo-key


# config-management.yaml

cat > config-management.yaml <<EOF
apiVersion: configmanagement.gke.io/v1
kind: ConfigManagement
metadata:
  name: config-management
spec:
  # clusterName is required and must be unique among all managed clusters
  clusterName: demo-cluster
  git:
    syncRepo: git@github.com:tgaillard1/anthos-demo.git
    syncBranch: master
    secretType: ssh
    policyDir: "."
EOF

kubectl apply -f config-management.yaml

nomos status to validate --> SYNCED

*********************************************************************
*********************************************************************

Adding Anthos Service Mesh -- Existing Cluster

*********************************************************************

curl --request POST \
--header "Authorization: Bearer $(gcloud auth print-access-token)" \
--data '' \
https://meshconfig.googleapis.com/v1alpha1/projects/${PROJECT_ID}:initialize


curl -Lo $WORKDIR/istio-1.4.6-asm.0-linux.tar.gz https://storage.googleapis.com/gke-release/asm/istio-1.4.6-asm.0-linux.tar.gz

curl -Lo $WORKDIR/istio-1.4.6-asm.0-linux.tar.gz.1.sig https://storage.googleapis.com/gke-release/asm/istio-1.4.6-asm.0-linux.tar.gz.1.sig
openssl dgst -verify - -signature $WORKDIR/istio-1.4.6-asm.0-linux.tar.gz.1.sig $WORKDIR/istio-1.4.6-asm.0-linux.tar.gz <<'EOF'
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEWZrGCUaJJr1H8a36sG4UUoXvlXvZ
wQfk16sxprI2gOJ2vFFggdq3ixF2h4qNBt0kI7ciDhgpwS8t+/960IsIgw==
-----END PUBLIC KEY-----
EOF

tar xzf istio-1.4.6-asm.0-linux.tar.gz

cd $WORKDIR/istio-1.4.6-asm.0

export PATH=$PWD/bin:$PATH

istioctl manifest apply --set profile=asm \
  --set values.global.trustDomain=${IDNS} \
  --set values.global.sds.token.aud=${IDNS} \
  --set values.nodeagent.env.GKE_CLUSTER_URL=https://container.googleapis.com/v1/projects/${PROJECT_ID}/locations/${CLUSTER_ZONE0}/clusters/${CLUSTER_NAME0} \
  --set values.global.meshID=${MESH_ID} \
  --set values.global.proxy.env.GCP_METADATA="${PROJECT_ID}|${PROJECT_NUMBER}|${CLUSTER_NAME0}|${CLUSTER_ZONE0}"


kubectl wait --for=condition=available --timeout=600s deployment --all -n istio-system

asmctl validate
asmctl validate --with-testing-workloads

kubectl label namespace default istio-injection=enabled --overwrite


&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&











~/testme/spinnaker-for-gcp/scripts/manage/add_gke_account.sh

kubectl config use-context gke_${DEVSHELL_PROJECT_ID}_${ZONE}_spinnaker-1

~/testme/spinnaker-for-gcp/scripts/manage/push_and_apply.sh

switch back to dev context and repeat

kubectx dev

~/testme/spinnaker-for-gcp/scripts/manage/add_gke_account.sh

kubectl config use-context gke_${DEVSHELL_PROJECT_ID}_${ZONE}_spinnaker-1

~/testme/spinnaker-for-gcp/scripts/manage/push_and_apply.sh


Install AWS Managed account

Install AWS CLI

curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

/usr/local/bin/aws --version

