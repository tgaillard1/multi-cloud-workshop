#   Multi-Cloud Workshop  
### Reference Implementation main document --> go/...

![Workshop Screenshot](images/multi-cloud-workshop.png?raw=true "Workshop Diagram")

Set Project and Zone
```
gcloud config set project gaillard-gcp 
gcloud config set compute/zone us-central1-a
```

Get All Workshop source code
```
git clone https://github.com/tgaillard1/multi-cloud-workshop.git
cd multi-cloud-workshop/
```

******************************************************
Workshop 1
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

*Install Helm