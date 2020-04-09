## Workshop 3 -- AI/ML Recommendation Engine

![Workshop Screenshot](images/workshop3-arch.png?raw=true "Workshop 3 Diagram")

### Prerequisites
*  A Google Cloud Platform Account
*  A Git Hub Account
*  Two projects are needed for this workshop

**NOTE** -- Skip the next step if you have already download the source code from the first workshop (1).

*  Get workshop source code
    ```shell
    git clone https://github.com/tgaillard1/multi-cloud-workshop.git
    cd ~/multi-cloud-workshop
    source ./env
    ```

### Set up environment

*  Create a new project for your builds on GCP:
+  Name should indicate build, e.g., "tg-build"
+  Enter your build project ID below in your shell

*  Set Build Project ID
    ```shell
    gcloud config set project REPLACE_WITH_YOUR_**BUILD**_PROJECT_ID
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
        anthos.googleapis.com \
        run.googleapis.com \
        firestore.googleapis.com \
        pubsub.googleapis.com \
        cloudscheduler.googleapis.com \
        cloudresourcemanager.googleapis.com
    ```
    
*  Set environment variables
    ```shell
    cd ~/multi-cloud-workshop
    source ./env
    ```

*  Set additional **Build** project variables
    ```shell
    export BUILD_PROJECT_ID=${DEVSHELL_PROJECT_ID}
    gcloud config set compute/zone ${CLUSTER_ZONE1} --project ${BUILD_PROJECT_ID}
    gcloud config set project ${BUILD_PROJECT_ID}
    export BUILD_PROJECT_NUMBER=$(gcloud projects describe $DEVSHELL_PROJECT_ID --format='value(projectNumber)')
    ```

A second project is needed for your deployments.  If you have completed Workshop 1 or 2 you can use that project for these deployments.
*  Set **Deployment** project variables
    ```shell
    export TEST_PROJECT_ID=REPLACE_WITH_YOUR_DEPLOYMENT_PROJECT_ID
    gcloud config set compute/zone ${CLUSTER_ZONE3} --project ${TEST_PROJECT_ID}
    ```

### Install Terraform IAC

*  Set environment
    ```shell
    cd ~/multi-cloud-workshop
    source ./env
    ```

*  Create bucket for  
```
gsutil mb -p ${BUILD_PROJECT_ID} -l us-central1 \
 gs://recommender-tf-state-$BUILD_PROJECT_ID
```

```
cd sample-iac
```

```
sed -i "s|__PROJECT_ID__|${TEST_PROJECT_ID}|g" ./terraform.tfvars

sed -i "s|__STATE_BUCKET_NAME__|recommender-tf-state-$BUILD_PROJECT_ID|g" ./backend.tf
```

```
git add terraform.tfvars backend.tf
git commit -m "Update variables"
git push origin master
```

# Create Credentials for GitHub
```
ssh-keygen -t rsa -b 4096 -C "timlgaillard@gmail.com"
```

```
cat ~/.ssh/id_rsa.pub
```

In your GitHub account, navigate to the IAC-REPO-NAME repository

Click on Settings -> Deploy Keys.

Click Add Deploy Key and paste in the SSH public key you copied. Choose a Title for the key.

Enable the check box "Allow write access"

Click Save.

# Local Credentials

Navigate back to your Cloud Shell session
Create the known_hosts file for GitHub. In your Cloud Shell session, run the command:

```
ssh-keyscan github.com >> ~/.ssh/known_hosts
```

```
gsutil mb -p ${BUILD_PROJECT_ID} -l us-central1 gs://github-keys-$BUILD_PROJECT_ID

gsutil cp ~/.ssh/id_rsa* gs://github-keys-$BUILD_PROJECT_ID
gsutil cp ~/.ssh/known_hosts gs://github-keys-$BUILD_PROJECT_ID
```

Generate a Personal Access Token for GitHub This token is used when performing Git operations using API calls that the recommender-parser service makes to generate pull requests, check-in updated IaC manifests.

In your GitHub account, in the upper-right corner of any page, click your profile photo, then click Settings.

In the left sidebar, click Developer settings.

In the left sidebar, click Personal access tokens

Click Generate new token.

Give your token a descriptive name.

Select the scopes as repo.

Click Generate token.

Copy the token to your clipboard.

3a1bfa49c81277b902addb389c5aca9d14159a3b -- 4-2 PAT

In your Cloud Shell session, create an environment variable.

```
export GITHUB_PAT=<personal-access-token-you-copied>
```



Connect your IAC-REPO-NAME Git repository to integrate with Cloud Build.

Go to the Cloud Build App page in the GitHub Marketplace. 

--> https://github.com/marketplace/google-cloud-build

Scroll down and click Setup with Google Cloud Build at the bottom of the page.
If prompted, Sign in to GitHub.
Select Only select repositories. Use the Select repositories drop-down list to only enable access to your IAC-REPO-NAME in the Cloud Build app.
Click Install.
Sign in to Google Cloud.

The Authorization page is displayed where you are asked to authorize the Google Cloud Build app to connect to Google Cloud.

Click Authorize Google Cloud Build by GoogleCloudBuild. You are redirected to the Cloud Console.

Select your Google Cloud project.

Enable the consent checkbox and click Next.

In the Select repository page that appears, select the IAC-REPO-NAME GitHub repo

Click Connect repository.

For more information, see Running builds on GitHub.

Click Create Push Trigger. This creates a trigger for you.

The directory that you copied has a cloudbuild.yaml file. This configuration file outlines the steps that a Cloud Build job executes when triggered.
```
gcloud projects add-iam-policy-binding $TEST_PROJECT_ID \
  --member serviceAccount:$BUILD_PROJECT_NUMBER@cloudbuild.gserviceaccount.com \
  --role roles/compute.admin \
  --project $TEST_PROJECT_ID

gcloud projects add-iam-policy-binding $TEST_PROJECT_ID \
  --member serviceAccount:$BUILD_PROJECT_NUMBER@cloudbuild.gserviceaccount.com \
  --role roles/iam.serviceAccountAdmin \
  --project $TEST_PROJECT_ID

gcloud projects add-iam-policy-binding $TEST_PROJECT_ID \
--member serviceAccount:$BUILD_PROJECT_NUMBER@cloudbuild.gserviceaccount.com \
--role roles/iam.securityAdmin \
--project $TEST_PROJECT_ID
```

Open the Build Triggers page in the Cloud Console.

Select build project, click Open.

Update the trigger's definition:

Click Edit to the right of Run Trigger.
In the Branch (regex) text field, type master.
For Build Configuration, select the Cloud Build configuration file option and type in cloudbuild.yaml in the text field.
Click Save.
To manually test the build trigger, click Run trigger on your trigger's entry in the triggers list.

Verify that a Compute Engine instance called tf-compute-1 and a service account called Terraform Recommender Test are created in your test project by the Cloud Build job you ran in the previous step

cd $HOME/recommender-iac-pipeline-nodejs-tutorial/parser-service
gcloud config set run/region us-central1
```
sed -i "s|__PROJECT_ID__|${TEST_PROJECT_ID}|g" ./stub/iam.json
sed -i "s|__PROJECT_ID__|${TEST_PROJECT_ID}|g" ./stub/vm.json
```

```
export IMAGE=gcr.io/$BUILD_PROJECT_ID/recommender-parser:1.0
```

```
gcloud builds submit --tag $IMAGE .
```

```
gcloud beta iam service-accounts create recommender-parser-sa \
  --description "Service account that the recommender-parser service uses to invoke other GCP services" \
  --display-name "recommender-parser-sa" \
  --project $BUILD_PROJECT_ID
```

```
gsutil iam ch serviceAccount:recommender-parser-sa@$BUILD_PROJECT_ID.iam.gserviceaccount.com:objectCreator,objectViewer \
gs://github-keys-$BUILD_PROJECT_ID

gsutil iam ch serviceAccount:recommender-parser-sa@$BUILD_PROJECT_ID.iam.gserviceaccount.com:objectCreator,objectViewer \
gs://recommender-tf-state-$BUILD_PROJECT_ID
```

```
 gcloud beta run deploy \
 --image=${IMAGE} \
 --no-allow-unauthenticated \
 --region us-central1 \
 --platform managed \
 --service-account recommender-parser-sa@$BUILD_PROJECT_ID.iam.gserviceaccount.com \
 --set-env-vars="GITHUB_ACCOUNT=github.com:tgaillard1,GITHUB_PAT=${GITHUB_PAT},SSH_KEYS_BUCKET=github-keys-${BUILD_PROJECT_ID},TERRAFORM_STATE_BUCKET=recommender-tf-state-$BUILD_PROJECT_ID" \
 --project $BUILD_PROJECT_ID \
 recommender-parser
```

Create Firestore

In Google Cloud Console, in your build project, navigate to the Firestore page.
When prompted for mode selection, click Select Native Mode.
Selectus-east1 as the default location.
Click Create Database.
Click Start Collection.
For Collection ID, type in applied-recommendations.
Click Save.

```
gcloud beta iam service-accounts create recommender-scheduler-sa \
  --description "Service Account used by Cloud Scheduler to invoke the recommender-parser service" \
  --display-name "recommender-scheduler-sa" \
  --project $BUILD_PROJECT_ID

gcloud beta run services add-iam-policy-binding recommender-parser \
--member=serviceAccount:recommender-scheduler-sa@$BUILD_PROJECT_ID.iam.gserviceaccount.com \
--role=roles/run.invoker \
--region=us-central1
```

```
gcloud beta run services list --platform managed --project $BUILD_PROJECT_ID
```

```
export RECOMMENDER_ROUTE_TO_INVOKE_IAM=https://recommender-parser-32zozzaz4q-uc.a.run.app/recommendation/iam
export RECOMMENDER_ROUTE_TO_INVOKE_VM=https://recommender-parser-32zozzaz4q-uc.a.run.app/recommendation/vm
```

```
gcloud beta scheduler jobs create http recommender-iam-scheduler \
  --project $BUILD_PROJECT_ID \
  --time-zone "America/Phoenix" \
  --schedule="0 */3 * * *" \
  --uri=$RECOMMENDER_ROUTE_TO_INVOKE_IAM \
  --description="Scheduler job to invoke recommendation pipeline" \
--oidc-service-account-email="recommender-scheduler-sa@$BUILD_PROJECT_ID.iam.gserviceaccount.com" \
  --headers="Content-Type=application/json" \
  --http-method="POST" \
  --message-body="{ \"repo\": \"iac-multi\", \"projects\": [\"$TEST_PROJECT_ID\"], \"stub\": true }"
```

```
gcloud beta scheduler jobs create http recommender-vm-scheduler \
  --project $BUILD_PROJECT_ID \
  --time-zone "America/Phoenix" \
  --schedule="0 */3 * * *" \
  --uri=$RECOMMENDER_ROUTE_TO_INVOKE_VM \
  --description="Scheduler job to invoke recommendation pipeline" \
--oidc-service-account-email="recommender-scheduler-sa@$BUILD_PROJECT_ID.iam.gserviceaccount.com" \
  --headers="Content-Type=application/json" \
  --http-method="POST" \
  --message-body="{ \"repo\": \"iac-multi\", \"projects\": [\"$TEST_PROJECT_ID\"], \"stub\": true }"
```

```
gcloud beta iam service-accounts create recommender-ci-subscription-sa \
  --description "Service Account used by Cloud Pub/Sub to push Cloud Build events to the recommender-parser service" \
  --display-name "recommender-ci-subscription-sa" \
  --project $BUILD_PROJECT_ID
```

```
gcloud projects add-iam-policy-binding $BUILD_PROJECT_ID \
  --member serviceAccount:recommender-ci-subscription-sa@$BUILD_PROJECT_ID.iam.gserviceaccount.com \
  --role roles/pubsub.publisher \
  --project $BUILD_PROJECT_ID

gcloud projects add-iam-policy-binding $BUILD_PROJECT_ID \
  --member serviceAccount:recommender-ci-subscription-sa@$BUILD_PROJECT_ID.iam.gserviceaccount.com \
  --role roles/pubsub.subscriber \
  --project $BUILD_PROJECT_ID

gcloud projects add-iam-policy-binding $BUILD_PROJECT_ID \
  --member serviceAccount:recommender-ci-subscription-sa@$BUILD_PROJECT_ID.iam.gserviceaccount.com \
  --role roles/run.invoker \
  --project $BUILD_PROJECT_ID

gcloud beta run services add-iam-policy-binding recommender-parser \
--member=serviceAccount:recommender-ci-subscription-sa@$BUILD_PROJECT_ID.iam.gserviceaccount.com \
--role=roles/run.invoker --region=us-central1
```

Navigate to Pub/Sub in Google Cloud Console.

Click the cloud-builds topic.

Click Create Subscription.

For Subscription ID, type recommender-service-build-events.

For Delivery Type, select Push.

Check Enable Authentication.

Select the service account recommender-ci-subscription-sathat you created.
Click Grant in response to the prompt message.
For Endpoint, type in your recommender-service URL appended by /ci.

Select Acknowledgement deadline as 60 seconds.

Keep rest of the defaults.

Click Create.

Run Scheduler

