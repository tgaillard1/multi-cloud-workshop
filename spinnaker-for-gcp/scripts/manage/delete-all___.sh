#!/usr/bin/env bash

# Ensure that you comment out the deletion commands for resources you'd rather not delete.

bold() {
  echo ". $(tput bold)" "$*" "$(tput sgr0)";
}

bold "Deleting cluster  in ..."
gcloud container clusters delete  --zone  --project 

bold "Deleting bucket ..."
gsutil rm -r 

bold "Deleting Cloud Source Repository ..."
gcloud source repos delete  --project=

bold "Deleting subscription  in ..."
gcloud pubsub subscriptions delete  --project 

bold "Deleting subscription  in ..."
gcloud pubsub subscriptions delete  --project 

bold "Deleting cloud function  in ..."
gcloud functions delete  --region  --project 

bold "Deleting redis instance  in ..."
gcloud redis instances delete  --region  --project 
