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
        cloudbuild.googleapis.com \
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

*  Create Bucket for Terraform State  
    ```shell
    gsutil mb -p ${BUILD_PROJECT_ID} -l us-central1 \
    gs://recommender-tf-state-$BUILD_PROJECT_ID
    ```

########################################
### Create a GitHub repository to serve as the sample IaC repository

*  Create Git Hub Repo
Login to your Git Hub account --> got to repositories --> select "New" --> Enter variables below:
+ Repository Name = iac-source-repo
+ Description = IAC source code repo for multi-cloud
+ --> Creat Repository

Copy Repo URL link and enter below

*  Create Input Variable for Config Management
    ```shell
    export IAC_REPO=iac-source-repo
    export ACCOUNT=YOUR_GIT_USER
    export REPO_URL=https://github.com/${ACCOUNT}/${IAC_REPO}.git
    ```

*  Initialize for Git Push
    ```shell
    cp -rf $BASE_DIR/recommender-iac-pipeline-nodejs-tutorial/sample-iac/ $HOME
    cd ~/sample-iac
    git init
    git config credential.helper
    git remote add origin $REPO_URL
    ```

*  Replace the placeholders in the files in this repository with yourtestproject ID and the Terraform Cloud Storage bucket name.
    ```shell
    sed -i "s|__PROJECT_ID__|${TEST_PROJECT_ID}|g" ./terraform.tfvars

    sed -i "s|__STATE_BUCKET_NAME__|recommender-tf-state-$BUILD_PROJECT_ID|g" ./backend.tf
    ```

*  Push Files to Git Repo
    ```shell
    git add .
    git commit -m "Initial commit"
    git push origin master
    ```

## Create Credentials for GitHub

*  Add deployment key to GIT repo
    ```shell
    ssh-keygen -t rsa -b 4096 -C "your_github_email@example.com"
    ```

Go to Git --> Repo --> iac-source-repo --> settings --> Deploy keys --> Add deploy key

--> Add a **Title** = iac-source-deploy-key

--> Copy contents of public key from command below to **Key** location:
    ```shell
    cat ${HOME}/.ssh/id_rsa.pub
    ```

--> Allow write access to GitHub

--> Add key

## Local Credentials

Navigate back to your Cloud Shell session
Create the known_hosts file for GitHub. In your Cloud Shell session, run the command:

*  Create theknown_hosts file for GitHub. In your Cloud Shell session, run the command:
    ```shell
    ssh-keyscan github.com >> ~/.ssh/known_hosts
    ```

*  Create a Cloud Storage bucket in yourbuild project and upload your SSH keys and known_hosts file to it. Replace SSH-KEYS-DIR with the path to the directory where you generated the SSH keys.
    ```shell
    gsutil mb -p ${BUILD_PROJECT_ID} -l us-central1 gs://github-keys-$BUILD_PROJECT_ID

    gsutil cp ~/.ssh/id_rsa* gs://github-keys-$BUILD_PROJECT_ID
    gsutil cp ~/.ssh/known_hosts gs://github-keys-$BUILD_PROJECT_ID
    ```


### Generate a Personal Access Token for GitHub 

This token is used when performing Git operations using API calls that the recommender-parser service makes to generate pull requests, check-in updated IaC manifests.

Login to your Git Hub account --> in the upper-right corner of any page, click your profile photo --> then click Settings.

In the left sidebar, click -->  Developer settings.

In the left sidebar, click --> Personal access tokens --> Click Generate new token --> enter variables below:
+ Note = Give your token a descriptive name
+ Select Scopes = repo
+ Click --> Generate token.

Copy the token to your clipboard for variable below

*  In your Cloud Shell session, create an environment variable.

    ```shell
    export GITHUB_PAT=<personal-access-token-you-copied>
    ```

### Connect your $IAC_REPO Git repository to integrate with Cloud Build.

Go to the Cloud Build App page in the GitHub Marketplace. 

--> https://github.com/marketplace/google-cloud-build

Scroll down and click Setup with Google Cloud Build at the bottom of the page.
If prompted, Sign in to GitHub.
Select Only select repositories. Use the Select repositories drop-down list to only enable access to your $IAC_REPO in the Cloud Build app.
Click Install.
Sign in to Google Cloud.

The Authorization page is displayed where you are asked to authorize the Google Cloud Build app to connect to Google Cloud.

Click Authorize Google Cloud Build by GoogleCloudBuild. You are redirected to the Cloud Console.

Select your Google Cloud project.

Enable the consent checkbox and click Next.

In the Select repository page that appears, select the $IAC_REPO GitHub repo

Click Connect repository.

For more information, see Running builds on GitHub.

Click Create Push Trigger. This creates a trigger for you.

*  The directory that you copied has a cloudbuild.yaml file. This configuration file outlines the steps that a Cloud Build job executes when triggered.
    ```shell
    steps:
    - name: hashicorp/terraform:0.12.0
    args: ['init']
    - name: hashicorp/terraform:0.12.0
    args: ['apply', '-auto-approve']
    ```


*  Add permissions to your Cloud Build service account to allow it to create service accounts, associate roles, and VM's
    ```shell
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


## Deploy the recommender-parser Cloud Run service

*  Change directories to the directory created by cloning the repository
    ```shell
    cd $BASE_DIR/recommender-iac-pipeline-nodejs-tutorial/parser-service
    gcloud config set run/region us-central1
    ```

*  The `parser-service` directory has a stub sub-directory which has a few sample payload JSONs for you to test the recommender-parser service with. Run the following sed commands to replace the **PROJECT_ID** placeholders in these JSONs with your test project ID.
    ```shell
    sed -i "s|__PROJECT_ID__|${TEST_PROJECT_ID}|g" ./stub/iam.json
    sed -i "s|__PROJECT_ID__|${TEST_PROJECT_ID}|g" ./stub/vm.json
    ```

*  Run the following command to create an environment variable for your Docker image.
    ```shell
    export IMAGE=gcr.io/$BUILD_PROJECT_ID/recommender-parser:1.0
    ```

*  Build the image and upload to Container Registry
    ```shell
    gcloud builds submit --tag $IMAGE .
    ```

*  Create a service account for the recommender-parser service to interact with other Google Cloud services in the pipeline. It is a good practice to grant granular permissions to your Cloud Run services, refer to Cloud Run service identity for more details.
    ```shell
    gcloud beta iam service-accounts create recommender-parser-sa \
    --description "Service account that the recommender-parser service uses to invoke other GCP services" \
    --display-name "recommender-parser-sa" \
    --project $BUILD_PROJECT_ID
    ```

*  The recommender-parser service needs to access the GitHub SSH keys and Terraform state you uploaded to Cloud Storage buckets created earlier. Add the service account as a member to the Cloud Storage bucket.
    ```shell
    gsutil iam ch serviceAccount:recommender-parser-sa@$BUILD_PROJECT_ID.iam.gserviceaccount.com:objectCreator,objectViewer \
    gs://github-keys-$BUILD_PROJECT_ID

    gsutil iam ch serviceAccount:recommender-parser-sa@$BUILD_PROJECT_ID.iam.gserviceaccount.com:objectCreator,objectViewer \
    gs://recommender-tf-state-$BUILD_PROJECT_ID
    ```
*  Give the recommender-parser service's service account access to Firestore and the Recommender API.
    ```shell
    gcloud projects add-iam-policy-binding $BUILD_PROJECT_ID \
    --member serviceAccount:recommender-parser-sa@$BUILD_PROJECT_ID.iam.gserviceaccount.com \
    --role roles/datastore.user

    gcloud projects add-iam-policy-binding $TEST_PROJECT_ID \
    --member serviceAccount:recommender-parser-sa@$BUILD_PROJECT_ID.iam.gserviceaccount.com \
    --role roles/recommender.iamAdmin

    gcloud projects add-iam-policy-binding $TEST_PROJECT_ID \
    --member serviceAccount:recommender-parser-sa@$BUILD_PROJECT_ID.iam.gserviceaccount.com \
    --role roles/recommender.iamViewer

    gcloud projects add-iam-policy-binding $TEST_PROJECT_ID \
    --member serviceAccount:recommender-parser-sa@$BUILD_PROJECT_ID.iam.gserviceaccount.com \
    --role roles/recommender.computeAdmin
    ```


*  Deploy the Cloud Run service, which is called recommender-parser, by running the command. Accept any system prompts.
    ```shell
    gcloud beta run deploy \
    --image=${IMAGE} \
    --no-allow-unauthenticated \
    --region us-central1 \
    --platform managed \
    --service-account recommender-parser-sa@$BUILD_PROJECT_ID.iam.gserviceaccount.com \
    --set-env-vars="GITHUB_ACCOUNT=github.com:${ACCOUNT},GITHUB_PAT=${GITHUB_PAT},SSH_KEYS_BUCKET=github-keys-${BUILD_PROJECT_ID},TERRAFORM_STATE_BUCKET=recommender-tf-state-$BUILD_PROJECT_ID" \
    --project $BUILD_PROJECT_ID \
    recommender-parser
    ```

Create Firestore

In Google Cloud Console, in your `build` project, navigate to the Firestore page.
When prompted for mode selection, click Select Native Mode.
Select `us-east1` as the default location.
Click Create Database.
Click Start Collection.
For Collection ID, type in `applied-recommendations`.
Click Save.


## Set up a Cloud Scheduler job

*  Create a service account that Cloud Scheduler jobs use to run the recommender-parser service.
    ```shell
    gcloud beta iam service-accounts create recommender-scheduler-sa \
    --description "Service Account used by Cloud Scheduler to invoke the recommender-parser service" \
    --display-name "recommender-scheduler-sa" \
    --project $BUILD_PROJECT_ID
    ```
*  Give the service account run/invoker role to be able to invoke the Cloud Run service. **Note - choose default for now (1)**
    ```shell
    gcloud beta run services add-iam-policy-binding recommender-parser \
    --member=serviceAccount:recommender-scheduler-sa@$BUILD_PROJECT_ID.iam.gserviceaccount.com \
    --role=roles/run.invoker \
    --region=us-central1
    ```

*  Get your recommender-service URL:
    ```shell
    gcloud beta run services list --platform managed --project $BUILD_PROJECT_ID
    ```

*  Create a variable for the endpoint that Cloud Scheduler jobs invoke. Replace RECOMMENDER-SERVICE-URL with the recommender-service URL you copied in the previous step.
    ```shell
    export RECOMMENDER_ROUTE_TO_INVOKE_IAM=RECOMMENDER-SERVICE-URL/recommendation/iam
    export RECOMMENDER_ROUTE_TO_INVOKE_VM=RECOMMENDER-SERVICE-URL/recommendation/vm
    ```

*  Create a Cloud Scheduler job called recommender-iam-scheduler.

Change the selected time-zone based on your location.
Replace <you-iac-repo> with the name of the GitHub repository you created.
The message body takes three inputs and you must construct it as outlined below:

*  repo: This is the name of your GitHub repository IAC-REPO-NAME that you created in Create a GitHub repository.

*  projects: A list / array of Google Cloud projects IDs that this IaC GitHub repository maps to. In this tutorial, it is your test project.

*  stub: Recommender generates Cloud IAM recommendations when a subset of permissions for a role have not been used for 60 days and VM sizing recommendations follow a similar pattern. For the purposes of testing this pipeline on demand, stub can be passed in as true so that the pipeline is tested using the sample Recommender payloads provided in the repository that you cloned for this tutorial.
    ```shell
    gcloud beta scheduler jobs create http recommender-iam-scheduler \
    --project $BUILD_PROJECT_ID \
    --time-zone "America/Phoenix" \
    --schedule="0 */3 * * *" \
    --uri=$RECOMMENDER_ROUTE_TO_INVOKE_IAM \
    --description="Scheduler job to invoke recommendation pipeline" \
    --oidc-service-account-email="recommender-scheduler-sa@$BUILD_PROJECT_ID.iam.gserviceaccount.com" \
    --headers="Content-Type=application/json" \
    --http-method="POST" \
    --message-body="{ \"repo\": \"$IAC_REPO\", \"projects\": [\"$TEST_PROJECT_ID\"], \"stub\": true }"
    ```

*  Create VM recommendation scheduler
    ```shell
    gcloud beta scheduler jobs create http recommender-vm-scheduler \
    --project $BUILD_PROJECT_ID \
    --time-zone "America/Phoenix" \
    --schedule="0 */3 * * *" \
    --uri=$RECOMMENDER_ROUTE_TO_INVOKE_VM \
    --description="Scheduler job to invoke recommendation pipeline" \
    --oidc-service-account-email="recommender-scheduler-sa@$BUILD_PROJECT_ID.iam.gserviceaccount.com" \
    --headers="Content-Type=application/json" \
    --http-method="POST" \
    --message-body="{ \"repo\": \"$IAC_REPO\", \"projects\": [\"$TEST_PROJECT_ID\"], \"stub\": true }"
    ```

## Additional steps
*  Create a service account that Pub/Sub uses to invoke the recommender-parser service endpoint.
    ```shell
    gcloud beta iam service-accounts create recommender-ci-subscription-sa \
    --description "Service Account used by Cloud Pub/Sub to push Cloud Build events to the recommender-parser service" \
    --display-name "recommender-ci-subscription-sa" \
    --project $BUILD_PROJECT_ID
    ```

*  The Pub/Sub service account should be associated with the roles it needs to be able to publish messages and invoke the recommender-parser service.
    ```shell
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
    ```

*  Add the recommender-ci-subscription-saservice account you created to the recommender-parser service as a member with the invoker role **Note -- choose default (1) for now
    ```shell
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

