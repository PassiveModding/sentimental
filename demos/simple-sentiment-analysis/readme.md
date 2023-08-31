# Sentiment Analysis on GCP 

## What is Sentiment Analysis?
Sentiment analysis is the process of determining whether a piece of writing is positive, negative or neutral. In this deployment we will use the Google Cloud Natural Language API to perform sentiment analysis on a piece of text.

## Overview
![Architecture](/images/architecture.png)

### Features
The application consists of several serverless components that interact with each other to provide a scalable and reliable architecture.

1. Producer Function: This acts as the entry point for new data, pushing it into the processing pipeline.
2. PubSub Queue: Data is queued here before being processed, ensuring a reliable and organized flow.
3. Consumer Function: Responsible for consuming data from the queue, utilizing the Google Cloud Natural Language API for sentiment analysis, and finally storing the processed data.
4. DataStore: The processed data finds its home here, providing a repository for easy retrieval and analysis.

Both the producer and consumer functions are deployed using Google Cloud Functions and written in dotnet 6 however Cloud Functions supports many [runtimes](https://cloud.google.com/functions/docs/concepts/exec#runtimes). The producer function is triggered by an http request and the consumer function is triggered by a pub/sub message. The producer function sends the message to a pub/sub topic. The consumer function reacts to the pub/sub message, forwarding it to the natural language API for sentiment analysis. After obtaining the sentiment score, the function sends results to datastore.

## Prerequisites
This tutorial can be completed entirely in the [Google Cloud Shell](https://console.cloud.google.com/cloudshelleditor). If you prefer to use your local machine, you will need the following:
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
- [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)

Note: Some steps may differ slightly if you are using your local machine.

### Before you begin
1. In the Google Cloud console, on the project selector page, select or create a Google Cloud project.
[Go to project selector](https://console.cloud.google.com/projectselector2/home/dashboard)
2. Make sure that billing is enabled for your Cloud project. [Learn how to confirm billing is enabled for your project](https://cloud.google.com/billing/docs/how-to/verify-billing-enabled#console).
3. Enable the required APIs
[Enable the APIs](https://console.cloud.google.com/flows/enableapi?apiid=iam.googleapis.com,cloudresourcemanager.googleapis.com,pubsub.googleapis.com,eventarc.googleapis.com,cloudfunctions.googleapis.com,run.googleapis.com,cloudbuild.googleapis.com,language.googleapis.com,firestore.googleapis.com).

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

### Building the Application
#### Setup
In a directory of your choosing, create the following files:
- `main.tf` - Terraform configuration
- `variables.tf` - Terraform variables
- `terraform.tfvars` - Terraform variable values

Additionally, create two directories named `producer` and `consumer`.

Add the following provider block to the `main.tf` file:
```terraform
provider "google" {  
  project = var.project_id
  region  = var.region
}
```

Create a new file named `variables.tf` in the same directory. This file will contain the variables that will be used in the Terraform configuration.
Add the following variable blocks to the `variables.tf` file:
```terraform
variable "project_id" {
  description = "The project ID to deploy to"
  type        = string
}

variable "region" {
  description = "The region to deploy to"
  type        = string
}
```

Create a new file named `terraform.tfvars` in the same directory. This file will contain the values for the variables that will be used in the Terraform configuration.
Add the following variable blocks to the `terraform.tfvars` file:
```terraform
project_id = "<PROJECT_ID>"
region     = "<REGION>"
```
Note: Replace `<PROJECT_ID>` and `<REGION>` with your project id and region.

#### Pub/Sub
We will use pub/sub to send messages between the producer and consumer functions. 
Add the following resource block to the `main.tf` file:
```terraform
resource "google_pubsub_topic" "sentiment" {
  name = "sentiment"
}
```

#### Storage Bucket
Cloud functions require a storage bucket to store the function code archive.

Add the following resource blocks to the `main.tf` file:
```terraform
resource "random_id" "bucket_id" {
  byte_length = 8
}

resource "google_storage_bucket" "functions" {
  name                     = "sentiment-functions-${random_id.bucket_id.hex}"
  location                 = var.region
  public_access_prevention = "enforced"
  force_destroy            = true
}
```
Note: Name must be unique across all of Google Cloud, if you get an error, try changing the name. We use the `random_id` resource to generate a random suffix to avoid this issue.

#### Datastore
We will use datastore to store the results of the sentiment analysis. Datastore is a serverless NoSQL document database built for automatic scaling, high performance, and ease of application development.

Add the following resource block to the `main.tf` file:
```terraform
resource "google_firestore_database" "datastore_mode_database" {
    name = "(default)"
    location_id = var.region
    type        = "DATASTORE_MODE"
}
```
Note: There are some issues with managing the `(default)` datastore db using terraform. If you encounter errors, try creating the database using the cli command `gcloud alpha firestore databases create --location=<REGION> --type=datastore-mode`. (Replace `<REGION>` with your region and make sure to omit the datastore block from your terraform)

#### Cloud Functions
We will use cloud functions to run our producer and consumer functions. Functions are single-purpose, stand-alone serverless functions that are hosted and managed by Google Cloud and used to build event driven applications. We will be using `dotnet6` as the runtime for our functions however you can use any of the [supported runtimes](https://cloud.google.com/functions/docs/concepts/exec#runtimes). You will not need to install the runtime on your machine since cloud functions will handle that for you.

Defining a cloud function in terraform is a multi-step process. You need source code for the function, a zip archive of the source code, and the function configuration.

Each function will consist of three terraform blocks and the application source code. The three blocks are:
- `data.archive_file` - This will zip our source code into an archive
- `google_storage_bucket_object` - This will upload the zip archive to our storage bucket
- `google_cloudfunctions2_function` - This will create the cloud function

Within the function block we will define the function name, runtime, entry point, source code, and environment variables. We will also define the event trigger for the consumer function.
- `name` - The name of the function
- `runtime` - The runtime for the function, in this case `dotnet6`
- `entry_point` - The entry point for the function, in this case the source code uses the namespace `Producer`/`Consumer` and the class `Function` so the entry point is `Producer.Function`/`Consumer.Function`
- `source` - The source code for the function will be uploaded to a storage bucket and referenced here
- `environment_variables` - Configuration values that will be available to the function at runtime.

##### Producer Function
The producer function will be triggered by an http request. It will then send the message to a pub/sub topic. We provide the topic id and project id as environment variables so the function knows where to send the message.

Add the following resource blocks to the `main.tf` file:
```terraform
resource "google_cloudfunctions2_function" "producer" {
  name        = "producer-function"
  location    = var.region

  build_config {
    runtime     = "dotnet6"
    entry_point = "Producer.Function"
    source {
      storage_source {
        bucket = google_storage_bucket.functions.name
        object = google_storage_bucket_object.producer.name
      }
    }
  }

  service_config {
    environment_variables = {
      OUTPUT_TOPIC_ID = google_pubsub_topic.sentiment.id
      PROJECT_ID      = var.project_id
    }
  }
}

resource "google_storage_bucket_object" "producer" {
  name   = format("%s#%s.zip", "producer", data.archive_file.producer.output_md5)
  bucket = google_storage_bucket.functions.name
  source = "./producer.zip"
}

data "archive_file" "producer" {
  type        = "zip"
  source_dir  = "./producer"
  output_path = "./producer.zip"
}
```
Note: The hash of the source code is used as part of the zip archive name. This ensures that the zip archive is updated when the source code changes.

##### Producer Source Code
Create the following files named `Function.cs` and `producer.csproj` in the `producer` directory. This file will contain the code for the producer function. This function will be triggered by an http request. It will then send the message to a pub/sub topic. We provide the topic id and project id as environment variables so the function knows where to send the message.

Add the following code to the `producer/Function.cs` file:
```csharp
using Google.Cloud.Functions.Framework;
using Microsoft.AspNetCore.Http;
using Google.Cloud.PubSub.V1;
using Microsoft.Extensions.Logging;

namespace Producer;

public class Function : IHttpFunction
{
    private readonly ILogger<Function> _logger;

    public Function(ILogger<Function> logger)
    {
        _logger = logger;
    }

    public async Task HandleAsync(HttpContext context)
    {
        // Get the message body from the request
        using var reader = new StreamReader(context.Request.Body);
        var messageBody = await reader.ReadToEndAsync();     

        var output_topic_id = Environment.GetEnvironmentVariable("OUTPUT_TOPIC_ID") ?? throw new Exception("OUTPUT_TOPIC_ID not set");
        var project_id = Environment.GetEnvironmentVariable("PROJECT_ID") ?? throw new Exception("PROJECT_ID not set");
        // get the topic name from the full topic id
        var topicName = new TopicName(project_id, output_topic_id.Split('/').Last());      

        var publisherClient = PublisherClient.Create(topicName);
        
        await publisherClient.PublishAsync(new PubsubMessage
        {
            Data = Google.Protobuf.ByteString.CopyFromUtf8(messageBody)
        });

        _logger.LogInformation("Message published to {output_topic}: {messageBody}", topicName, messageBody);

        context.Response.StatusCode = StatusCodes.Status200OK;
        await context.Response.WriteAsync($"Message published to {topicName}: {messageBody}");
    }
}
```

Add the following code to the `producer/producer.csproj` file:
```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net6.0</TargetFramework>
    <RootNamespace>producer</RootNamespace>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Google.Cloud.Functions.Hosting" Version="2.1.0" />
    <PackageReference Include="Google.Cloud.PubSub.V1" Version="3.6.0" />    
  </ItemGroup>
</Project>
```
Note: The `csproj` file contains the project configuration. We need to add the `Google.Cloud.Functions.Hosting` and `Google.Cloud.PubSub.V1` packages as dependencies.

##### Consumer Function
The consumer function reacts to a pub/sub message, forwarding it to the natural language API for sentiment analysis. After obtaining the sentiment score, the function sends results to datastore.

Add the following resource blocks to the `main.tf` file:
```terraform
resource "google_cloudfunctions2_function" "consumer" {
  name        = "consumer-function"
  location = var.region

  build_config {
    runtime     = "dotnet6"
    entry_point = "Consumer.Function"
    source {
      storage_source {
        bucket = google_storage_bucket.functions.name
        object = google_storage_bucket_object.consumer.name
      }
    }
  }

  service_config {
    environment_variables = {
      PROJECT_ID = var.project_id
    }
  }

  event_trigger {
    event_type   = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic = google_pubsub_topic.sentiment.id
    trigger_region = var.region
    retry_policy = "RETRY_POLICY_DO_NOT_RETRY"
  }
}

resource "google_storage_bucket_object" "consumer" {
  name   = format("%s#%s.zip", "consumer", data.archive_file.consumer.output_md5)
  bucket = google_storage_bucket.functions.name
  source = "./consumer.zip"
}

data "archive_file" "consumer" {
  type        = "zip"
  source_dir  = "./consumer"
  output_path = "./consumer.zip"
}
```

##### Consumer Source Code
In the consumer directory, create Function.cs and consumer.csproj files. Function.cs holds the consumer function code triggered by a pub/sub message. This function sends the message to the natural language API for sentiment scoring. Results are then sent to the datastore.

Add the following code to the `consumer/Function.cs` file:
```csharp
using CloudNative.CloudEvents;
using Google.Cloud.Datastore.V1;
using Google.Cloud.Functions.Framework;
using Google.Cloud.Language.V1;
using Google.Events.Protobuf.Cloud.PubSub.V1;
using Microsoft.Extensions.Logging;

namespace Consumer;

public class Function : ICloudEventFunction<MessagePublishedData>
{
    
    private readonly ILogger<Function> _logger;

    public Function(ILogger<Function> logger)
    {
        _logger = logger;
    }

    public async Task HandleAsync(CloudEvent cloudEvent, MessagePublishedData data, CancellationToken cancellationToken)
    {
        _logger.LogInformation("Received Pub/Sub message with data: {data}", data.Message.TextData);
        var projectId = Environment.GetEnvironmentVariable("PROJECT_ID") ?? throw new Exception("PROJECT_ID not set");
        var db = DatastoreDb.Create(projectId);
        var client = await LanguageServiceClient.CreateAsync(cancellationToken);
        var sentimentResult = await client.AnalyzeSentimentAsync(new Document()
        {
            Content = data.Message.TextData,
            Type = Document.Types.Type.PlainText
        }, cancellationToken);   
        float sentiment = sentimentResult.DocumentSentiment.Score;        

        _logger.LogInformation("Sentiment score: {score}", sentiment);
        var keyFactory = db.CreateKeyFactory("sentiment");

        Google.Cloud.Datastore.V1.Entity entity = new()
        {
            Key = keyFactory.CreateIncompleteKey(),
            ["created"] = DateTime.UtcNow,
            ["text"] = data.Message.TextData,
            ["score"] = sentiment
        };
        
        using (var transaction = await db.BeginTransactionAsync())
        {
            transaction.Insert(entity);
            var commitResponse = await transaction.CommitAsync();
            var insertedKey = commitResponse.MutationResults[0].Key;
            _logger.LogInformation("Inserted key: {key}", insertedKey);
        }
    }
}
```

Add the following code to the `consumer/consumer.csproj` file:
```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net6.0</TargetFramework>
    <RootNamespace>consumer</RootNamespace>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Google.Apis.CloudNaturalLanguage.v1" Version="1.61.0.3130" />
    <PackageReference Include="Google.Cloud.Datastore.V1" Version="4.5.0" />
    <PackageReference Include="Google.Cloud.Functions.Hosting" Version="2.1.0" />
    <PackageReference Include="Google.Cloud.Language.V1" Version="3.3.0" />
    <PackageReference Include="Google.Cloud.PubSub.V1" Version="3.6.0" />
    <PackageReference Include="Google.Events.Protobuf" Version="1.3.0" />
  </ItemGroup>
</Project>
```

#### Terraform Outputs
We will use terraform outputs to get the producer and consumer endpoints.
Add the following output blocks to the `main.tf` file:
```terraform
output "producer_endpoint" {
  value = google_cloudfunctions2_function.producer.url
}
output "consumer_endpoint" {
  value = google_cloudfunctions2_function.consumer.url
}
```

### Initialize Terraform
Run the following command to initialize Terraform plugins and build the `.terraform` directory:
```bash
terraform init
```

### Validate the Terraform configuration
Preview the resources that will be created by Terraform:
```bash
terraform plan --var-file terraform.tfvars
```
Note: If prompted, Authorize Cloud Shell to make Google Cloud Platform API calls by clicking `Authorize`.

### Apply the Terraform configuration
Deploy the application by applying the Terraform configuration. When prompted, enter `yes` to confirm:
```bash
terraform apply --var-file terraform.tfvars
```
Note: If there is an error creating the datastore database, it may already exist in your project. If that is the case you can simply remove the datastore block from the terraform configuration and reapply.

## Testing the Application
Post a message to the producer endpoint using curl in your terminal:
```bash
curl -H "Authorization: bearer $(gcloud auth print-identity-token)" $(terraform output -raw producer_endpoint) --data 'My good review'
```
We authorize the request with an identity token since unauthorized requests are blocked by default. The producer function will be triggered by the request. We use the terraform output to get the url of the endpoint.

The producer function will start and send your message to pubsub. The consumer function will then start and send the message to the natural language api. The natural language api will return the sentiment score. The consumer function will then send the results to the datastore.

Observe the response from the producer function:
```bash
Message published to projects/<PROJECT_ID>/topics/sentiment: My good review
```

Check cloud datastore to see the results.
https://console.cloud.google.com/datastore/databases/-default-/entities;kind=sentiment

![Datastore](/images/datastore_results.png)

## Try updating the application
Try updating the application by changing the message that we send back to the client. Update the response in `producer/Function.cs` file to the following:
```csharp
await context.Response.WriteAsync($"Hello World: {messageBody}");
```

Redeploy the application by running the following command:
```bash
terraform apply --var-file terraform.tfvars
```

Test the producer function again:
```bash
curl -H "Authorization: bearer $(gcloud auth print-identity-token)" $(terraform output -raw producer_endpoint) --data 'My new review'
```

Observe the new response:
```bash
Hello World: My new review
```

## Clean up
After completing this tutorial, you can delete everything that was created so that you don't incur further costs.

Terraform lets you remove all the resources defined in the configuration file by running the `terraform destroy` command:
```bash
terraform destroy
```
Enter `yes` to allow Terraform to delete your resources.

Note: The datastore database will not be deleted since the `(default)` database cannot be deleted without first clearing all entities. You can manage entities from the console and delete the database from the gcloud cli using the following command `gcloud alpha firestore databases delete --database="(default)"`. Subsequent applies will fail if the database is not deleted however you may delete the datastore block from the terraform configuration to avoid this issue.