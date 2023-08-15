# Sentiment Analysis

## Description
The Sentiment Analysis Application is a straightforward and efficient tool for analyzing the sentiment of text data using the Google Cloud Natural Language API. The application is designed to process input data through a series of steps, from data ingestion to sentiment analysis, and store the results for further analysis.

## Features
The application consists of several components that work seamlessly together to achieve sentiment analysis:
1. Producer Function: This acts as the entry point for new data, pushing it into the processing pipeline.
2. PubSub Queue: Data is queued here before being processed, ensuring a reliable and organized flow.
3. Consumer Function: Responsible for consuming data from the queue, utilizing the Google Cloud Natural Language API for sentiment analysis, and finally storing the processed data.
4. DataStore: The processed data finds its home here, providing a repository for easy retrieval and analysis.

Both the producer and consumer functions are deployed using Google Cloud Functions, offering a scalable and serverless architecture.

## Getting Started
### GCloud Setup
Create a GCP project and enable the following API:
- [Service Usage API](https://console.cloud.google.com/apis/library/serviceusage.googleapis.com) - allows terraform to manage APIs required to run the application.

The following apis are required but will be managed by terraform:
- [Cloud Functions](https://console.cloud.google.com/apis/library/cloudfunctions.googleapis.com) - Used to deploy the producer and consumer functions.
- [Cloud Pub/Sub](https://console.cloud.google.com/apis/library/pubsub.googleapis.com) - Used to queue data for processing.
- [Cloud Datastore](https://console.cloud.google.com/apis/library/datastore.googleapis.com) - Used to store processed data.
- [Cloud Storage](https://console.cloud.google.com/apis/library/storage-component.googleapis.com) - Used to store the cloud function source code.
- [Cloud Natural Language API](https://console.cloud.google.com/apis/library/language.googleapis.com) - Used to analyze the sentiment of text data.
- [Cloud Eventarc API](https://console.cloud.google.com/apis/library/eventarc.googleapis.com) - Used to trigger the consumer function on Pub/Sub events.
- [Cloud Resource Manager API](https://console.cloud.google.com/apis/library/cloudresourcemanager.googleapis.com)
- [Identity and Access Management (IAM) API](https://console.cloud.google.com/apis/library/iam.googleapis.com)

Enable Datastore mode for App Engine in the [Data store Settings](https://console.cloud.google.com/datastore/welcome)

### CI/CD Setup
The CI/CD pipeline is configured using Github Actions. The workflow is triggered on every push to the `main` branch.
The workflow consists actions for terraform management and cloud function deployment.

#### Terraform
To set up the necessary Google Cloud resources, follow these steps:

1. Create a bucket in your GCP project for backend purposes. This will be used to store the terraform state.
Update the `main.tf`  and fill in the bucket name in the `terraform` block.

2. Create a service account and obtain the JSON key file. Ensure that the service account has the required roles for creating and managing the resources you need.
- Note: The service account must 
In your github repository, create a secret named `TFSTATE_SA_KEY` and paste the contents of the JSON key file. 
Additionally create variables for `PROJECT_ID` and `REGION` and fill in the values.

#### Cloud Functions
1. Run `terraform init` to initialize the terraform backend.
2. Run `terraform plan` to see the changes that will be made.
3. Run `terraform apply` to create the necessary resources.

### Cloud Testing
To test the cloud deployment, send a POST request to the producer function with the following bodies:
```bash
curl -H "Authorization: bearer $(gcloud auth print-identity-token)" $(terraform output -raw producer_endpoint) --data 'My good review'
```
Check cloud datastore to see the results.
https://console.cloud.google.com/datastore/databases/-default-/entities;kind=Sentiment


### Local Development Environment
Setting up a functional local deployment environment is streamlined for developers. Utilizing Google's emulator for PubSub and Datastore, you can easily emulate the entire deployment process. 
The `docker-compose-local.yml` file provides detailed configuration.

To start the local deployment, execute the following command:
```bash
docker compose -f docker-compose-local.yml up
```

Try testing the producer function by sending a POST request to `http://localhost:8086` with the following bodies:
```bash
curl -X POST -d 'hello world' localhost:8086
curl -X POST -d 'hello good world' localhost:8086
curl -X POST -d 'hello bad world' localhost:8086
```
Observe the results in the console or in the Datastore emulator. 
You should see the sentiment score for each text.
Note: When using the emulator, we mock the sentiment analysis so if `good` is in the text, the score will be 1, and if `bad` is in the text, the score will be -1 and if neither is in the text, the score will be 0.


### TODO:
1. Find a way to impersonate the service account while running terraform apply locally
2. Find a way to set-up and impersonate producer_invoker for testing the producer function
3. Allow calling the real sentiment analysis api while running locally
4. Find a way to destroy the datastore resources with terraform destroy (currently this level of granularity is not supported by terraform)
5. Document the terraform using terraform-docs
6. Document the code and have a separate readme for the code
7. Diagrams of the architecture
8. Images and step-by-step setup for each component