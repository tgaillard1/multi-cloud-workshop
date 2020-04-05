#   Multi-Cloud Workshop -- AI/ML -- Anthos
## Reference Architecture

![Workshop Screenshot](images/multi-cloud-arch.png?raw=true "Workshop Diagram")

## Overview

This workshop is intended to provide a modern solution for multicloud deployments utilizing options for common opensource and hyperscaler cloud services.  The image above gives an overview of the main components involved but the intent is to provide a framework to modularize the assets so you can easily swap your application of choice for the given task.  The workshop is divided into three self contained sub-workshops in order to promote consumability for the end user. 

The main concepts that are promoted:
*  Declarative modeling via IAC
*  Federation for multiple Kubernetes clusters
*  Unified service mesh (Istio)
*  AI/ML driven infrastructure management
*  Cloud agnostic deployments

## Prerequisites
*  A Google Cloud Platform Account
*  [Enable the Compute Engine, Container Engine, and Container Builder APIs](https://console.cloud.google.com/flows/enableapi?apiid=compute_component,container,cloudbuild.googleapis.com)

Set Project and Zone
```
gcloud config set project REPLACE_WITH_YOUR_PROJECT_ID 
```

Get All Workshop source code
```
git clone https://github.com/tgaillard1/multi-cloud-workshop.git
cd multi-cloud-workshop/
```

