#   Workshop 1 -- Continuous Integration -- Jenkins 

<img src="https://github.com/tgaillard1/multi-cloud-workshop/blob/master/images/jenkins-ci-arch.png" alt="Workshop 1 Diagram" width="1500" height="400"/>

## Prerequisites
*  A Google Cloud Platform Account
*  A Git Hub Account
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
    sourcerepo.googleapis.com \
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

Apply operator to cluster
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
````
kubectl label namespace default istio-injection=enabled --overwrite
````

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

    ```
    helm version
    Client: &version.Version{SemVer:"v2.14.1", GitCommit:"5270352a09c7e8b6e8c9593002a73535276507c0", GitTreeState:"clean"}
    Server: &version.Version{SemVer:"v2.14.1", GitCommit:"5270352a09c7e8b6e8c9593002a73535276507c0", GitTreeState:"clean"}
    ```


### Configure and Install Jenkins
You will use a custom [values file](https://github.com/kubernetes/helm/blob/master/docs/chart_template_guide/values_files.md) to add the GCP specific plugin necessary to use service account credentials to reach your Cloud Source Repository.

1. Use the Helm CLI to deploy the chart with your configuration set.

    ```
    helm install -n cd stable/jenkins -f $BASE_DIR/continuous-integration-on-kubernetes/jenkins/values.yaml --version 1.2.2 --wait
    ```

1. Once that command completes ensure the Jenkins pod goes to the `Running` state and the container is in the `READY` state:

    ```
    kubectl get pods
    NAME                          READY     STATUS    RESTARTS   AGE
    cd-jenkins-7c786475dd-vbhg4   2/2       Running   0          1m
    ```
    
1. Configure the Jenkins service account to be able to deploy to the cluster. 

    ```
    kubectl create clusterrolebinding jenkins-deploy --clusterrole=cluster-admin --serviceaccount=default:cd-jenkins

    clusterrolebinding.rbac.authorization.k8s.io/jenkins-deploy created
    ```

1. Run the following command to setup port forwarding to the Jenkins UI from the Cloud Shell

    ```
    export POD_NAME=$(kubectl get pods -l "app.kubernetes.io/component=jenkins-master" -o jsonpath="{.items[0].metadata.name}")
    kubectl port-forward $POD_NAME 9080:8080 >> /dev/null &
    ```

1. Now, check that the Jenkins Service was created properly:

    ```
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

2. To get to the Jenkins user interface, click on the Web Preview button![](../docs/img/web-preview.png) in cloud shell, then click “Preview on port 9080”:

![](docs/img/preview-8080.png)

You should now be able to log in with username `admin` and your auto generated password.

![](docs/img/jenkins-login.png)

### Your progress, and what's next (Optional if you want to deploy an application)
You've got a Kubernetes cluster managed by Google Container Engine. You've deployed:

* a Jenkins Deployment
* a (non-public) service that exposes Jenkins to its agent containers

You have the tools to build a continuous deployment pipeline. Now you need a sample app to deploy continuously.

## The sample app
You'll use a very simple sample application - `gceme` - as the basis for your CD pipeline. `gceme` is written in Go and is located in the `sample-app` directory in this repo. When you run the `gceme` binary on a GCE instance, it displays the instance's metadata in a pretty card:

![](images/info_card.png)

The binary supports two modes of operation, designed to mimic a microservice. In backend mode, `gceme` will listen on a port (9080 by default) and return GCE instance metadata as JSON, with content-type=application/json. In frontend mode, `gceme` will query a backend `gceme` service and render that JSON in the UI you saw above. It looks roughly like this:

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

### (Option 1 -- Git Hub Repository) Create a repository for the sample app
Here you'll create your own copy of the `gceme` sample app in a Git Hub Repository you own.

1. Create Git Hub Repo
Login to your Git Hub account --> got to repositories --> select "New" --> Enter variables below:
+ Repository Name = gceme
+ Description = Sample app for Jenkins on multi-cloud
+ --> Creat Repository

Copy Repo URL link and enter below

Create Input Variable for Config Management
```shell
export APP_REPO="gceme"
export ACCOUNT=YOUR_GIT_USER
export APP_REPO_URL=https://github.com/${ACCOUNT}/${APP_REPO}.git
```

1. Change directories to `sample-app` of the repo you cloned previously, then initialize the git repository.

   **Be sure to replace _REPLACE_WITH_YOUR_PROJECT_ID_ with the name of your Google Cloud Platform project**

1. Initialize for Git Push
    ```shell
    cd $BASE_DIR/continuous-integration-on-kubernetes/sample-app
    git init
    git config credential.helper
    git remote add origin $APP_REPO_URL
    ```

1. Push Files to Git Repo
    ```shell
    git add .
    git commit -m "Initial commit"
    git push origin master
    ```

To see sample code go to --> https://github.com/${ACCOUNT}/${APP_REPO}.git

### (Option 2 -- Google Source Repository) Create a repository for the sample app
Here you'll create your own copy of the `gceme` sample app in [Cloud Source Repository](https://cloud.google.com/source-repositories/docs/).

1. Change directories to `sample-app` of the repo you cloned previously, then initialize the git repository.

   **Be sure to replace _REPLACE_WITH_YOUR_PROJECT_ID_ with the name of your Google Cloud Platform project**

    ```shell
    cd $BASE_DIR/continuous-integration-on-kubernetes/sample-app
    git init
    git config credential.helper gcloud.sh
    gcloud source repos create gceme
    git remote add origin https://source.developers.google.com/p/${PROJECT_ID}/r/gceme
    ```
    cd $BASE_DIR/continuous-integration-on-kubernetes/sample-app
    git init
    git config credential.helper
    git remote add origin https://github.com/tgaillard1/gceme.git


1. Ensure git is able to identify you:

    ```shell
    export EMAIL=$(gcloud config get-value account)
    git config --global user.email "$EMAIL"
    git config --global user.name "$USER"
    ```


1. Add, commit, and push all the files:

    ```shell
    git add .
    git commit -m "Initial commit"
    git push origin master
    ```
To see sample code go to --> https://source.cloud.google.com/${PROJECT_ID}/gceme

-----
1. Add application to Kubernetes
    ```shell
    cd $BASE_DIR/continuous-integration-on-kubernetes/sample-app
    kubectl create ns production
    kubectl label namespace production istio-injection=enabled --overwrite
    ```

    ```shell
    kubectl --namespace=production apply -f k8s/production
    kubectl --namespace=production apply -f k8s/canary
    kubectl --namespace=production apply -f k8s/services
    ```

    ```shell
    kubectl --namespace=production scale deployment gceme-frontend-production --replicas=4
    ```

    ```shell
    kubectl --namespace=production get service gceme-frontend

    When the process completes, an IP address is displayed in the EXTERNAL-IP column.
    ```

## Create a pipeline
You'll now use Jenkins to define and run a pipeline that will test, build, and deploy your copy of `gceme` to your Kubernetes cluster. You'll approach this in phases. Let's get started with the first.

### Phase 1: Add your service account credentials
First we will need to configure our GCP credentials in order for Jenkins to be able to access our code repository

1. In the Jenkins UI, Click “Credentials” on the left
1. Click either of the “(global)” links (they both route to the same URL)
1. Click “Add Credentials” on the left
1. From the “Kind” dropdown, select “Google Service Account from metadata”
1. Click “OK”

You should now see 2 Global Credentials. Make a note of the name of second credentials as you will reference this in Phase 2:

![](docs/img/jenkins-credentials.png)


### Phase 2: Create a job
This lab uses [Jenkins Pipeline](https://jenkins.io/solutions/pipeline/) to define builds as groovy scripts.

Navigate to your Jenkins UI and follow these steps to configure a Pipeline job (hot tip: you can find the IP address of your Jenkins install with `kubectl get ingress --namespace jenkins`):

1. Click the “Jenkins” link in the top left of the interface

1. Click the **New Item** link in the left nav

1. Name the project **sample-app**, choose the **Multibranch Pipeline** option, then click `OK`

1. Click `Add Source` and choose `git`

1. Paste the **HTTPS clone URL** of your `sample-app` repo on Cloud Source Repositories into the **Project Repository** field.
    It will look like: https://source.developers.google.com/p/REPLACE_WITH_YOUR_PROJECT_ID/r/gceme

1. From the Credentials dropdown select the name of new created credentials from the Phase 1. It should have the format `PROJECT_ID service account`.

1. Under 'Scan Multibranch Pipeline Triggers' section, check the 'Periodically if not otherwise run' box and se the 'Interval' value to 1 minute.

1. Click `Save`, leaving all other options with their defaults

  ![](docs/img/clone_url.png)

A job entitled "Branch indexing" was kicked off to see identify the branches in your repository. If you refresh Jenkins you should see the `master` branch now has a job created for it.

The first run of the job will fail until the project name is set properly in the next step.

### Phase 3:  Modify Jenkinsfile, then build and test the app

Create a branch for the canary environment called `canary`
   
   ```shell
    $ git checkout -b canary
   ```

The [`Jenkinsfile`](https://jenkins.io/doc/book/pipeline/jenkinsfile/) is written using the Jenkins Workflow DSL (Groovy-based). It allows an entire build pipeline to be expressed in a single script that lives alongside your source code and supports powerful features like parallelization, stages, and user input.

Modify your `Jenkinsfile` script so it contains the correct project name on line 2.

**Be sure to replace _REPLACE_WITH_YOUR_PROJECT_ID_ on line 2 with your project name:**

Don't commit the new `Jenkinsfile` just yet. You'll make one more change in the next section, then commit and push them together.

### Phase 4: Deploy a [canary release](http://martinfowler.com/bliki/CanaryRelease.html) to canary
Now that your pipeline is working, it's time to make a change to the `gceme` app and let your pipeline test, package, and deploy it.

The canary environment is rolled out as a percentage of the pods behind the production load balancer.
In this case we have 1 out of 5 of our frontends running the canary code and the other 4 running the production code. This allows you to ensure that the canary code is not negatively affecting users before rolling out to your full fleet.
You can use the [labels](http://kubernetes.io/docs/user-guide/labels/) `env: production` and `env: canary` in Google Cloud Monitoring in order to monitor the performance of each version individually.

1. In the `sample-app` repository on your workstation open `html.go` and replace the word `blue` with `orange` (there should be exactly two occurrences):

  ```html
  //snip
  <div class="card orange">
  <div class="card-content white-text">
  <div class="card-title">Backend that serviced this request</div>
  //snip
  ```

1. In the same repository, open `main.go` and change the version number from `1.0.0` to `2.0.0`:

   ```go
   //snip
   const version string = "2.0.0"
   //snip
   ```

1. `git add Jenkinsfile html.go main.go`, then `git commit -m "Version 2"`, and finally `git push origin canary` your change.

1. When your change has been pushed to the Git repository, navigate to your Jenkins job. Click the "Scan Multibranch Pipeline Now" button.

  ![](docs/img/first-build.png)

1. Once the build is running, click the down arrow next to the build in the left column and choose **Console Output**:

  ![](docs/img/console.png)

1. Track the output for a few minutes and watch for the `kubectl --namespace=production apply...` to begin. When it starts, open the terminal that's polling canary's `/version` URL and observe it start to change in some of the requests:

   ```
   1.0.0
   1.0.0
   1.0.0
   1.0.0
   2.0.0
   2.0.0
   1.0.0
   1.0.0
   1.0.0
   1.0.0
   ```

   You have now rolled out that change to a subset of users.

1. Once the change is deployed to canary, you can continue to roll it out to the rest of your users by creating a branch called `production` and pushing it to the Git server:

   ```shell
    $ git checkout master
    $ git merge canary
    $ git push origin master
   ```
1. In a minute or so you should see that the master job in the sample-app folder has been kicked off:

    ![](docs/img/production.png)

1. Clicking on the `master` link will show you the stages of your pipeline as well as pass/fail and timing characteristics.

    ![](docs/img/production_pipeline.png)

1. Open the terminal that's polling canary's `/version` URL and observe that the new version (2.0.0) has been rolled out and is serving all requests.

   ```
   2.0.0
   2.0.0
   2.0.0
   2.0.0
   2.0.0
   2.0.0
   2.0.0
   2.0.0
   2.0.0
   2.0.0
   ```

1. Look at the `Jenkinsfile` in the project to see how the workflow is written.

### Phase 5: Deploy a development branch
Often times changes will not be so trivial that they can be pushed directly to the canary environment. In order to create a development environment from a long lived feature branch
all you need to do is push it up to the Git server and let Jenkins deploy your environment. In this case you will not use a loadbalancer so you'll have to access your application using `kubectl proxy`,
which authenticates itself with the Kubernetes API and proxies requests from your local machine to the service in the cluster without exposing your service to the internet.

#### Deploy the development branch

1. Create another branch and push it up to the Git server

   ```shell
   $ git checkout -b new-feature
   $ git push origin new-feature
   ```

1. Open Jenkins in your web browser and navigate to the sample-app job. You should see that a new job called "new-feature" has been created and your environment is being created.

1. Navigate to the console output of the first build of this new job by:

  * Click the `new-feature` link in the job list.
  * Click the `#1` link in the Build History list on the left of the page.
  * Finally click the `Console Output` link in the left navigation.

1. Scroll to the bottom of the console output of the job, and you will see instructions for accessing your environment:

   ```
   deployment "gceme-frontend-dev" created
   [Pipeline] echo
   To access your environment run `kubectl proxy`
   [Pipeline] echo
   Then access your service via http://localhost:8001/api/v1/proxy/namespaces/new-feature/services/gceme-frontend:80/
   [Pipeline] }
   ```

#### Access the development branch

1. Open a new Google Cloud Shell terminal by clicking the `+` button to the right of the current terminal's tab, and start the proxy:

   ```shell
   $ kubectl proxy
   ```

1. Return to the original shell, and access your application via localhost:

   ```shell
   $ curl http://localhost:8001/api/v1/proxy/namespaces/new-feature/services/gceme-frontend:80/
   ```

1. You can now push code to the `new-feature` branch in order to update your development environment.

1. Once you are done, merge your `new-feature ` branch back into the  `canary` branch to deploy that code to the canary environment:

   ```shell
   $ git checkout canary
   $ git merge new-feature
   $ git push origin canary
   ```

1. When you are confident that your code won't wreak havoc in production, merge from the `canary` branch to the `master` branch. Your code will be automatically rolled out in the production environment:

   ```shell
   $ git checkout master
   $ git merge canary
   $ git push origin master
   ```

1. When you are done with your development branch, delete it from the server and delete the environment in Kubernetes:

   ```shell
   $ git push origin :new-feature
   $ kubectl delete ns new-feature
   ```

## Extra credit: deploy a breaking change, then roll back
Make a breaking change to the `gceme` source, push it, and deploy it through the pipeline to production. Then pretend latency spiked after the deployment and you want to roll back. Do it! Faster!

Things to consider:

* What is the Docker image you want to deploy for roll back?
* How can you interact directly with the Kubernetes to trigger the deployment?
* Is SRE really what you want to do with your life?

## Clean up
Clean up is really easy, but also super important: if you don't follow these instructions, you will continue to be billed for the Google Container Engine cluster you created.

To clean up, navigate to the [Google Developers Console Project List](https://console.developers.google.com/project), choose the project you created for this lab, and delete it. That's it.