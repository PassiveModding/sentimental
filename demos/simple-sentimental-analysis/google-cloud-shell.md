# Sentiment Analysis on GCP 

## What is Sentiment Analysis?
Sentiment analysis is the process of determining whether a piece of writing is positive, negative or neutral. It’s also known as opinion mining, deriving the opinion or attitude of a speaker. A common use case for this technology is to discover how people feel about a particular topic. In this deployment we will use the Google Cloud Natural Language API to perform sentiment analysis on a piece of text.

![Architecture](./images/architecture.png)

## Prerequisites
This tutorial can be completed entirely in the [Google Cloud Shell](https://console.cloud.google.com/cloudshelleditor). If you prefer to use your local machine, you will need the following:
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
- [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)

Note: Some steps may differ slightly if you are using your local machine.

### Before you begin
1. In the Google Cloud console, on the project selector page, select or create a Google Cloud project.
[GO TO PROJECT SELECTOR](https://console.cloud.google.com/projectselector2/home/dashboard)
2. Make sure that billing is enabled for your Cloud project. [Learn how to confirm billing is enabled for your project](https://cloud.google.com/billing/docs/how-to/verify-billing-enabled#console).
3. Enable the required APIs
[Enable the APIs](https://console.cloud.google.com/flows/enableapi?apiid=iam.googleapis.com,cloudresourcemanager.googleapis.com,pubsub.googleapis.com,eventarc.googleapis.com,cloudfunctions.googleapis.com,run.googleapis.com,cloudbuild.googleapis.com,language.googleapis.com,firestore.googleapis.com).

- [Identity and Access Management (IAM) API](https://console.cloud.google.com/apis/library/iam.googleapis.com)  allows terraform to manage IAM roles and permissions.
- [Cloud Resource Manager API](https://console.cloud.google.com/apis/library/cloudresourcemanager.googleapis.com) allows terraform to manage your project.
- [Pub/Sub API](https://console.cloud.google.com/apis/library/pubsub.googleapis.com) allows terraform to manage pub/sub topics.
    - [Eventarc API](https://console.cloud.google.com/apis/library/eventarc.googleapis.com) enables cloud function triggers from pub/sub topics.
- [Cloud Functions API](https://console.cloud.google.com/apis/library/cloudfunctions.googleapis.com) allows terraform to manage cloud functions.
    - [Cloud Run API](https://console.cloud.google.com/apis/library/run.googleapis.com) required as functions backend
    - [Cloud Build API](https://console.cloud.google.com/apis/library/cloudbuild.googleapis.com) required for cloud run
- [Firestore API](https://console.cloud.google.com/apis/library/firestore.googleapis.com) allows terraform to manage firestore databases.
    - [Datastore API](https://console.cloud.google.com/apis/library/datastore.googleapis.com) required for datastore mode
- [Natural Language API](https://console.cloud.google.com/apis/library/language.googleapis.com) allows the consumer function to call the natural language api.

### Open Cloud Shell
This can be done by clicking the cloud shell icon in the top right corner of the console.

### Ensure your project is selecter and set
```bash
gcloud config get-value project
```
Note:  the project is not set, you can set it with the following command: `gcloud config set project <PROJECT_NAME>`

### Create the default datastore database
```bash
gcloud firestore databases create --location=$REGION --type=datastore-mode
```
Note: This will use the default database id `(default)`. Using an alternative is outside the scope of this tutorial. You will need to specify a region for the database. You can find a list of available regions [here](https://cloud.google.com/firestore/docs/locations).

### Preparing the Application
In the Cloud Shell, perform the following steps:
1. Clone the sample code repository to your Cloud Shell instance:
```bash
git clone https://github.com/passivemodding/sentimental.git
```
2. Change the working directory to the sample code directory:
```bash
cd ./sentimental/demos/simple-sentimental-analysis
```


3. Review the Terraform configuration files in the directory. These files define the resources that will be created by Terraform. The `main.tf` file contains the configuration for the resources that will be created. The `variables.tf` file contains the variables that will be used in the configuration. 

4. Review the `functions/producer/Function.cs` file. This file contains the code for the producer function. This function will be triggered by an http request. It will then send the message to a pub/sub topic.

5. Review the `functions/consumer/Function.cs` file. This file contains the code for the consumer function. This function will be triggered by a pub/sub message. It will then send the message to the natural language api. The natural language api will return the sentiment score. The consumer function will then send the results to the datastore.

6. Rename `terraform.auto.tfvars.example` to `terraform.auto.tfvars` and update the variables with your project id and region. Terraform will automatically load these variables when you run `terraform plan` or `terraform apply`.

### Initialize Terraform
In Cloud Shell, run the following command to initialize Terraform plugins and build the `.terraform` directory:
```bash
terraform init
```

### Validate the Terraform configuration
Preview the resources that will be created by Terraform:
```bash
terraform plan
```

### Apply the Terraform configuration
Deploy the application by applying the Terraform configuration. When prompted, enter `yes` to confirm:
```bash
terraform apply
```

### Testing the Application
Post a message to the producer endpoint
```bash
curl -H "Authorization: bearer $(gcloud auth print-identity-token)" $(terraform output -raw producer_endpoint) --data 'My good review'
```

The producer function will start and send your message to pubsub. The consumer function will then start and send the message to the natural language api. The natural language api will return the sentiment score. The consumer function will then send the results to the datastore.

Check cloud datastore to see the results.
https://console.cloud.google.com/datastore/databases/-default-/entities;kind=sentiment

![Datastore](/images/datastore_results.png)

## Clean up
After completing this tutorial, you can delete everything that was created so that you don't incur further costs.

Terraform lets you remove all the resources defined in the configuration file by running the `terraform destroy` command:
```bash
terraform destroy
```
Enter `yes` to allow Terraform to delete your resources.

Note: Datastore will not be deleted as it was created outside of terraform. You can delete it by running the following command:
```bash
gcloud firestore databases delete --quiet
```