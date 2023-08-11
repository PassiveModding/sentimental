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
### Terraform Setup
To set up the necessary Google Cloud resources, follow these steps:

1. Create a bucket in your GCP project for backend purposes. This will be used to store the terraform state.
Update the `main.tf` file with your bucket name.
2. Create a service account and obtain the JSON key file. Ensure that the service account has the required roles, such as:
    - Cloud Functions Admin (for deploying the functions)
    - Pub/Sub Admin (for creating the pubsub topic and subscription)
    - Storage Admin (for the cloud function code storage bucket)
    - Datastore User (for accessing the datastore)
3. Modify the `terraform.auto.tfvars` file with your configuration:
```bash
project_id = "your-project-id"
region = "your-region"
```
4. Navigate to the `terraform` directory and run `terraform init`, followed by `terraform apply` to create the required resources.

### CI/CD Setup
The CI/CD pipeline is configured using Github Actions. The workflow is triggered on every push to the `main` branch.
The workflow consists of the following actions:
1. Build the dotnet functions for the producer and consumer.
2. Zip the functions and upload them to the cloud function storage bucket.

Setup the following secrets in your Github repository:
`FUNCTION_STORAGE_SERVICE_ACCOUNT_JSON` - The JSON key file for the service account with the required roles.
`FUNCTION_STORAGE_BUCKET` - The name of the cloud function storage bucket.

### Local Development Environment
Setting up a functional local deployment environment is streamlined for developers. Utilizing Google's emulator for PubSub and Datastore, you can easily emulate the entire deployment process. 
The `docker-compose.yml` file provides detailed configuration.

To start the local deployment, execute the following command:
```bash
docker compose up
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