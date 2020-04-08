#!/usr/bin/env bash

# Ensure that you comment out the deletion commands for resources you'd rather not delete.

bold() {
  echo ". $(tput bold)" "$*" "$(tput sgr0)";
}

bold "Deleting cluster spinnaker1 in demo2-tg..."
gcloud container clusters delete spinnaker1 --zone us-east1-c --project demo2-tg

bold "Deleting bucket gs://spinnaker1-7rnlzzuq5qe2jiu5es76-1586364250..."
gsutil rm -r gs://spinnaker1-7rnlzzuq5qe2jiu5es76-1586364250

bold "Deleting Cloud Source Repository spinnaker1-config..."
gcloud source repos delete spinnaker1-config --project=demo2-tg

bold "Deleting subscription spinnaker1-gcr-pubsub-subscription in demo2-tg..."
gcloud pubsub subscriptions delete spinnaker1-gcr-pubsub-subscription --project demo2-tg

bold "Deleting subscription spinnaker1-gcb-pubsub-subscription in demo2-tg..."
gcloud pubsub subscriptions delete spinnaker1-gcb-pubsub-subscription --project demo2-tg

bold "Deleting cloud function spinnaker1AuditLog in demo2-tg..."
gcloud functions delete spinnaker1AuditLog --region us-east1 --project demo2-tg

bold "Deleting redis instance spinnaker1 in demo2-tg..."
gcloud redis instances delete spinnaker1 --region us-east1 --project demo2-tg

bold "Deleting IAM policy binding for role roles/cloudbuild.builds.editor from spinnaker1-acc-1586364250@demo2-tg.iam.gserviceaccount.com in demo2-tg..."
gcloud projects remove-iam-policy-binding demo2-tg --member serviceAccount:spinnaker1-acc-1586364250@demo2-tg.iam.gserviceaccount.com --role roles/cloudbuild.builds.editor

bold "Deleting IAM policy binding for role roles/container.admin from spinnaker1-acc-1586364250@demo2-tg.iam.gserviceaccount.com in demo2-tg..."
gcloud projects remove-iam-policy-binding demo2-tg --member serviceAccount:spinnaker1-acc-1586364250@demo2-tg.iam.gserviceaccount.com --role roles/container.admin

bold "Deleting IAM policy binding for role roles/logging.logWriter from spinnaker1-acc-1586364250@demo2-tg.iam.gserviceaccount.com in demo2-tg..."
gcloud projects remove-iam-policy-binding demo2-tg --member serviceAccount:spinnaker1-acc-1586364250@demo2-tg.iam.gserviceaccount.com --role roles/logging.logWriter

bold "Deleting IAM policy binding for role roles/monitoring.admin from spinnaker1-acc-1586364250@demo2-tg.iam.gserviceaccount.com in demo2-tg..."
gcloud projects remove-iam-policy-binding demo2-tg --member serviceAccount:spinnaker1-acc-1586364250@demo2-tg.iam.gserviceaccount.com --role roles/monitoring.admin

bold "Deleting IAM policy binding for role roles/pubsub.admin from spinnaker1-acc-1586364250@demo2-tg.iam.gserviceaccount.com in demo2-tg..."
gcloud projects remove-iam-policy-binding demo2-tg --member serviceAccount:spinnaker1-acc-1586364250@demo2-tg.iam.gserviceaccount.com --role roles/pubsub.admin

bold "Deleting IAM policy binding for role roles/storage.admin from spinnaker1-acc-1586364250@demo2-tg.iam.gserviceaccount.com in demo2-tg..."
gcloud projects remove-iam-policy-binding demo2-tg --member serviceAccount:spinnaker1-acc-1586364250@demo2-tg.iam.gserviceaccount.com --role roles/storage.admin

bold "Deleting service account spinnaker1-acc-1586364250@demo2-tg.iam.gserviceaccount.com in demo2-tg..."
gcloud iam service-accounts delete spinnaker1-acc-1586364250@demo2-tg.iam.gserviceaccount.com --project demo2-tg
