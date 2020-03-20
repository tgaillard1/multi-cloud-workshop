Create kubernetes Cluster for CI/CD
```
cd continuous-integration-on-kubernetes

gcloud container clusters create jenkins-ci \
--num-nodes 2 \
--enable-autoscaling \
--min-nodes 1 \
--max-nodes 5 \
--zone us-central1-a \
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

&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
gcloud services enable \
    container.googleapis.com \
    compute.googleapis.com \
    stackdriver.googleapis.com \
    meshca.googleapis.com \
    meshtelemetry.googleapis.com \
    meshconfig.googleapis.com \
    iamcredentials.googleapis.com \
    anthos.googleapis.com


export PROJECT_ID=$(gcloud config list --format 'value(core.project)' 2>/dev/null)
export PROJECT_NUMBER=$(gcloud projects describe ${PROJECT_ID} --format="value(projectNumber)")
export CLUSTER_NAME=jenkins-ci
export CLUSTER_ZONE=us-central1-a
export IDNS=${PROJECT_ID}.svc.id.goog
export MESH_ID="proj-${PROJECT_NUMBER}"
gcloud config set compute/zone ${CLUSTER_ZONE}

curl --request POST \
  --header "Authorization: Bearer $(gcloud auth print-access-token)" \
  --data '' \
  https://meshconfig.googleapis.com/v1alpha1/projects/${PROJECT_ID}:initialize

gcloud container clusters get-credentials ${CLUSTER_NAME}

kubectl create clusterrolebinding cluster-admin-binding \
  --clusterrole=cluster-admin \
  --user="$(gcloud config get-value core/account)"


Download the Anthos Service Mesh installation file to your current working directory:

curl -LO https://storage.googleapis.com/gke-release/asm/istio-1.4.6-asm.0-linux.tar.gz


curl -LO https://storage.googleapis.com/gke-release/asm/istio-1.4.6-asm.0-linux.tar.gz.1.sig
openssl dgst -verify - -signature istio-1.4.6-asm.0-linux.tar.gz.1.sig istio-1.4.6-asm.0-linux.tar.gz <<'EOF'
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEWZrGCUaJJr1H8a36sG4UUoXvlXvZ
wQfk16sxprI2gOJ2vFFggdq3ixF2h4qNBt0kI7ciDhgpwS8t+/960IsIgw==
-----END PUBLIC KEY-----
EOF

tar xzf istio-1.4.6-asm.0-linux.tar.gz

cd istio-1.4.6-asm.0
export PATH=$PWD/bin:$PATH

istioctl manifest apply --set profile=asm \
  --set values.global.trustDomain=${IDNS} \
  --set values.global.sds.token.aud=${IDNS} \
  --set values.nodeagent.env.GKE_CLUSTER_URL=https://container.googleapis.com/v1/projects/${PROJECT_ID}/locations/${CLUSTER_ZONE}/clusters/${CLUSTER_NAME} \
  --set values.global.meshID=${MESH_ID} \
  --set values.global.proxy.env.GCP_METADATA="${PROJECT_ID}|${PROJECT_NUMBER}|${CLUSTER_NAME}|${CLUSTER_ZONE}"

kubectl wait --for=condition=available --timeout=600s deployment --all -n istio-system

asmctl validate
asmctl validate --with-testing-workloads








&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&

------
### Install Helm


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


### Configure and Install Jenkins
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

Go to --> https://source.cloud.google.com/REPLACE_WITH_YOUR_PROJECT_ID/gceme
