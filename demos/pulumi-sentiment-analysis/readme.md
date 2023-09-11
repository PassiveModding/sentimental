# Pulumi, Dotnet, GCP, Sentiment Analysis
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
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
- [Pulumi](https://www.pulumi.com/docs/install/)
- [Dotnet 6.0](https://dotnet.microsoft.com/download)

## Setup and Deployment
Create a new project in GCP (or use an existing one), make sure you have IAM permissions to manage the resources we will create in this project.

Make sure your project is set in the gcloud cli
```bash
gcloud config set project <project-id>
```

Enable required apis [here](https://console.cloud.google.com/flows/enableapi?apiid=iam.googleapis.com,cloudresourcemanager.googleapis.com,pubsub.googleapis.com,eventarc.googleapis.com,cloudfunctions.googleapis.com,run.googleapis.com,cloudbuild.googleapis.com,language.googleapis.com,firestore.googleapis.com).

- [Pub/Sub API](https://console.cloud.google.com/apis/library/pubsub.googleapis.com) allows terraform to manage pub/sub topics.
    - [Eventarc API](https://console.cloud.google.com/apis/library/eventarc.googleapis.com) enables cloud function triggers from pub/sub topics.
- [Cloud Functions API](https://console.cloud.google.com/apis/library/cloudfunctions.googleapis.com) allows terraform to manage cloud functions.
    - [Cloud Run API](https://console.cloud.google.com/apis/library/run.googleapis.com) required as functions backend
    - [Cloud Build API](https://console.cloud.google.com/apis/library/cloudbuild.googleapis.com) required for cloud run
- [Firestore API](https://console.cloud.google.com/apis/library/firestore.googleapis.com) allows terraform to manage firestore databases.
    - [Datastore API](https://console.cloud.google.com/apis/library/datastore.googleapis.com) required for datastore mode
- [Natural Language API](https://console.cloud.google.com/apis/library/language.googleapis.com) allows the consumer function to call the natural language api.

Create the default datastore db
```bash
gcloud alpha firestore databases create --database="(default)" --location="<region>" --type="datastore-mode"
```
Note: Multitenancy for datastore is currently in alpha and lacks support for the dotnet client library, as such we will create the default datastore db outside of our pulumi stack and import it into our stack rather than creating and deleting it as part of our stack.

Authorise the application default login so Pulumi can interact with GCP
```bash
gcloud auth application-default login
```

### Building the application
#### Install dotnet function templates
```bash
dotnet new install Google.Cloud.Functions.Templates
```

#### Producer function
Create a new dotnet http function project (in the project root directory)
```bash
dotnet new gcf-http -n producer
cd producer
dotnet add package Google.Cloud.PubSub.V1
```

Check your .csproj and see if it matches the following:
```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net6.0</TargetFramework>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Google.Cloud.Functions.Hosting" Version="2.1.0" />
    <None Include="appsettings*.json" CopyToOutputDirectory="PreserveNewest" />
    <PackageReference Include="Google.Cloud.PubSub.V1" Version="3.6.0" />
  </ItemGroup>
</Project>
```

In the `Function.cs` file add the following code:
```csharp
using Google.Cloud.Functions.Framework;
using Google.Cloud.PubSub.V1;
using Grpc.Core;
using Microsoft.AspNetCore.Http;
using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;

namespace Producer;

public class Function : IHttpFunction
{
    public async Task HandleAsync(HttpContext context)
    {
        // read the message body
        using var reader = new StreamReader(context.Request.Body);
        var messageBody = await reader.ReadToEndAsync();

        // get our environment variables and configure the topic output
        var output_topic_id = Environment.GetEnvironmentVariable("OUTPUT_TOPIC_ID") ?? throw new Exception("OUTPUT_TOPIC_ID not set");
        var project_id = Environment.GetEnvironmentVariable("PROJECT_ID") ?? throw new Exception("PROJECT_ID not set");
        var topicName = new TopicName(project_id, output_topic_id.Split('/').Last());
        
        var emulatorHost = Environment.GetEnvironmentVariable("PUBSUB_EMULATOR_HOST");
        var publisherClient = emulatorHost == null ? PublisherClient.Create(topicName) : new PublisherClientBuilder
        {
            Endpoint = emulatorHost,
            ChannelCredentials = ChannelCredentials.Insecure,
            TopicName = topicName
        }.Build();

        // publish the message to the topic
        await publisherClient.PublishAsync(new PubsubMessage
        {
            Data = Google.Protobuf.ByteString.CopyFromUtf8(messageBody)
        });

        // return a success message with a 200 status code
        context.Response.StatusCode = StatusCodes.Status200OK;
        await context.Response.WriteAsync($"Message published to {topicName}: {messageBody}");
    }
}
```

You can check the full code [here](./producer/Function.cs).

#### Consumer function
Create a new dotnet event function project (in the project root directory)
```bash
dotnet new gcf-untyped-event -n consumer
cd consumer
dotnet add package Google.Apis.CloudNaturalLanguage.v1
dotnet add package Google.Cloud.Datastore.V1
dotnet add package Google.Cloud.Language.V1
dotnet add package Google.Cloud.PubSub.V1
dotnet add package Google.Events.Protobuf
```

Check your .csproj and see if it matches the following:
```xml
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net6.0</TargetFramework>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Google.Apis.CloudNaturalLanguage.v1" Version="1.61.0.3130" />
    <PackageReference Include="Google.Cloud.Datastore.V1" Version="4.6.0" />
    <PackageReference Include="Google.Cloud.Functions.Hosting" Version="2.1.0" />
    <PackageReference Include="Google.Cloud.Language.V1" Version="3.3.0" />
    <PackageReference Include="Google.Cloud.PubSub.V1" Version="3.6.0" />
    <PackageReference Include="Google.Events.Protobuf" Version="1.3.0" />
    <None Include="appsettings*.json" CopyToOutputDirectory="PreserveNewest" />
  </ItemGroup>
</Project>
```

In the `Function.cs` file add the following code:
```csharp
using CloudNative.CloudEvents;
using Google.Cloud.Datastore.V1;
using Google.Cloud.Functions.Framework;
using Google.Cloud.Language.V1;
using Google.Events.Protobuf.Cloud.PubSub.V1;
using Grpc.Core;
using System;
using System.Threading;
using System.Threading.Tasks;

namespace Consumer;

public class Function : ICloudEventFunction<MessagePublishedData>
{
    public async Task HandleAsync(CloudEvent cloudEvent, MessagePublishedData data, CancellationToken cancellationToken)
    {
        // get our environment variables
        var projectId = Environment.GetEnvironmentVariable("PROJECT_ID") ?? throw new Exception("PROJECT_ID not set");

        // configure the datastore client
        var datastoreEmulatorHost = Environment.GetEnvironmentVariable("DATASTORE_EMULATOR_HOST"); 
        var db = datastoreEmulatorHost == null ? DatastoreDb.Create(projectId) : new DatastoreDbBuilder()
        {
            Endpoint = datastoreEmulatorHost,
            ChannelCredentials = ChannelCredentials.Insecure,
            ProjectId = projectId
        }.Build();

        // configure the language client
        var client = await LanguageServiceClient.CreateAsync(cancellationToken);

        var sentimentResult = await client.AnalyzeSentimentAsync(new Document()
        {
            // Get the text from the pubsub message
            Content = data.Message.TextData,
            Type = Document.Types.Type.PlainText
        }, cancellationToken);  

        // create a new entity to store in datastore
        var keyFactory = db.CreateKeyFactory("sentiment");
        Google.Cloud.Datastore.V1.Entity entity = new()
        {
            Key = keyFactory.CreateIncompleteKey(),
            ["created"] = DateTime.UtcNow,
            ["text"] = data.Message.TextData,
            ["score"] = sentimentResult.DocumentSentiment.Score,
            ["weight"] = sentimentResult.DocumentSentiment.Magnitude
        };

        // insert the entity into datastore
        using var transaction = await db.BeginTransactionAsync();
        transaction.Insert(entity);
        var commitResponse = await transaction.CommitAsync();

        Console.WriteLine($"Saved entity: {entity.Key}");
        Console.WriteLine($"Sentiment score: {sentimentResult.DocumentSentiment.Score}");
        Console.WriteLine($"Sentiment weight: {sentimentResult.DocumentSentiment.Magnitude}");
        Console.WriteLine($"Text: {data.Message.TextData}");
    }
}
```
Note the changes we made to the template:
- We changed the class to implement `ICloudEventFunction<MessagePublishedData>` so it can be triggered by a pub/sub message.
- We added the `MessagePublishedData` as a parameter to the `HandleAsync` method so we can access the pub/sub message data.
- We made the `HandleAsync` method async so we can use the async pub/sub client methods.
- We added using statements for the datastore and language client libraries.

You can check the full code [here](./consumer/Function.cs).

#### Locally testing the functions
I have a short guide on testing these specific functions locally by using gcloud emulators, docker and docker-compose [here](./testing-locally.md)

We added emulator support to the functions by allowing a custom endpoint for Pub/Sub and Datastore via the `PUBSUB_EMULATOR_HOST` and `DATASTORE_EMULATOR_HOST` environment variables so we can use the emulators instead of the real services. Docker is used to run the emulators and the functions. Docker-compose is used to orchestrate the containers and specify the environment variables.

### Deploying the application
Create a new pulumi c# project from the project root directory
```bash
mkdir pulumi && cd pulumi
pulumi new gcp-csharp
```
Note: Pulumi supports multiple different languages and cloud providers, see https://www.pulumi.com/docs/get-started/ for more information.

If it's your first time using pulumi you'll be prompted to provide an access token to pulumi cloud, follow the instructions to get a token and paste it into the terminal.

Follow the prompts to create a new project, I used the following values:
```bash
project name: pulumi-sentiment-analysis
project description: A simple sentiment analysis application
stack name: dev
gcp:project: <your gcp project id>
```

### Let's take a look at the default project pulumi created for us
```csharp
using Pulumi;
using Pulumi.Gcp.Storage;
using System.Collections.Generic;

return await Deployment.RunAsync(() =>
{
    // Create a GCP resource (Storage Bucket)
    var bucket = new Bucket("my-bucket", new BucketArgs
    {
        Location = "US"
    });

    // Export the DNS name of the bucket
    return new Dictionary<string, object?>
    {
        ["bucketName"] = bucket.Url
    };
});
```

We can get a basic overview of how pulumi works by looking at this code.
First we import the pulumi library.
Then we call `Deployment.RunAsync` to run our pulumi program. Within the Function call we define the resources that we want to create. In this case a storage bucket. We can see that we are creating a new `Bucket` resource and passing in a `BucketArgs` object. This object contains the properties we want to configure on the bucket. We are specifying the location of the bucket as `US`. Finally we are returning a dictionary of outputs we want to see when we run `pulumi up`. In this case we are returning the url of the bucket.

Let's remove the default code and start from scratch.

## Define infrastructure components
The components we will create are:
- Pub/Sub Topic
- Producer Function
- Consumer Function
- Storage Bucket
- Datastore Database (We already created this during project setup so we will import it into our stack rather than creating it as part of our stack)

Let's take a moment to think about the dependencies between these components.
- The producer function depends on the pub/sub topic to exist before it can be created since it needs to know the topic name to publish to.
- The consumer function depends on the pub/sub topic to exist before it can be created since it needs to know the topic name to subscribe to.
- The functions depend on the storage bucket to exist before they can be created since they need to pull the function code from the bucket.
- The datastore database does not depend on any other resources to exist before it can be created.
- The pub/sub topic does not depend on any other resources to exist before it can be created.

We can use this information to think about the order in which we should create our resources. We should create pub/sub topic and storage bucket first since they don't depend on any other resources. Then we can import the datastore database. And lastly we can create the functions since they depend on the datastore database, pub/sub topic and storage bucket.

### Configuration
There are a few variables we will need to specify to configure our stack. 
We want to deploy some of our resources to a specific region so rather than hardcoding the region we will use the `Config` object to specify the region. We can access the region in our program using the `Config` object.

We already specified the project id when we created the pulumi project so we can access it in our program using the `Config` object. If you go to the `Pulumi.dev.yaml` file in the `config` section you will see the project id is already specified. It has the prefix `gcp` because we specified the project id using the `gcp:project` flag when we created the pulumi project. 
```csharp
// access values under the default prefix ie. pulumi-sentiment-analysis:region: <region>
var config = new Config();
var region = config.Require("region");
// access values under the gcp prefix ie. gcp:project: <project_id>
var gcpConfig = new Config("gcp");
var project_id = gcpConfig.Require("project");
```

Pulumi will require these variables to be present when we call `pulumi up` and will throw an error if they are not present. You can take a look at the `Pulumi.dev.yaml` file in the `config` section to see the values we specified when we created the pulumi project. We will address adding the region value to the `Pulumi.dev.yaml` file later.

### Infrastructure components
Within the `Deployment.RunAsync` function we will define the resources we want to create. We will start by creating the pub/sub topic and storage bucket since they don't depend on any other resources.

### Pub/Sub
```csharp
 var topic = new Topic("sentiment-analysis");
```

### Storage Bucket
```csharp
var bucket = new Bucket("function-storage-bucket", new BucketArgs
{
    Location = "US"
});
```

### Datastore
```csharp
var dataStore = new Database("(default)", new DatabaseArgs
{
    LocationId = region,
    Type = "DATASTORE_MODE"
}, new CustomResourceOptions
{
    // deleting the default database will not succeed if it contains entities so we retain it
    RetainOnDelete = true,
    ImportId = "(default)"
});
```

Note using `CustomResourceOptions` lets us specify options that are not a part of the resource schema. In this case we are specifying that we want to retain the database when we delete the stack. This is because deleting the default database will not succeed if it contains entities. Additionally we use `ImportId` to specify the id of the database we want to import since we created it outside of our pulumi stack.

### Producer Function
The producer function needs to reference it's source code from the storage bucket, we can do this by creating a new `BucketObject` resource to upload the source code to the bucket. We will use the `FileAsset` class to reference the source code from the local file system.
```csharp
// Make sure we don't already have a zip files in the project root directory
if (File.Exists("../producer.zip"))
    File.Delete("../producer.zip");
// Delete the bin and obj directories so we don't zip them up
if (Directory.Exists("../producer/bin"))
    Directory.Delete("../producer/bin", true);
if (Directory.Exists("../producer/obj"))
    Directory.Delete("../producer/obj", true);

// Zip the producer function source code
// note, we use CompressionLevel.NoCompression sinze zipping with other methods can be non-deterministic
ZipFile.CreateFromDirectory("../producer", "../producer.zip", CompressionLevel.NoCompression, false); 
// Upload the producer source code to the bucket
var producer_source = new BucketObject("producer-source", new BucketObjectArgs
{
    Bucket = bucket.Name,
    Source = new FileAsset("../producer.zip")
});   
```

Next we need to configure the producer function to use the source code we just uploaded to the bucket. We can do this by referencing the `BucketObject` resource we just created in the `Source` property of the `FunctionBuildConfigArgs` object.
```csharp
var producer_function = new Function("producer-function", new FunctionArgs
{
    Location = region,
    BuildConfig = new FunctionBuildConfigArgs
    {
        Runtime = "dotnet6",
        EntryPoint = "Producer.Function",
        Source = new FunctionBuildConfigSourceArgs
        {
            StorageSource = new FunctionBuildConfigSourceStorageSourceArgs
            {
                Bucket = bucket.Name,
                Object = producer_source.Name
            }
        }
    },
    ServiceConfig = new FunctionServiceConfigArgs
    {
        EnvironmentVariables = new InputMap<string>
        {
            ["PROJECT_ID"] = project_id,
            ["OUTPUT_TOPIC_ID"] = topic.Id
        }
    }
});
```

If we follow this code we
- Create a zip file from the producer function source code
- Upload the producer source code to the bucket
- Create a new function resource
- Configure the function to use the source code we just uploaded to the bucket.
    - Cloud Functions will automatically unzip the source code when it deploys the function
- Configure the function to use the pub/sub topic we created earlier by specifying the topic id as an environment variable

### Consumer Function
We will use the same approach to reference the consumer function source code from the storage bucket.

```csharp
if (File.Exists("../consumer.zip"))
    File.Delete("../consumer.zip");
if (Directory.Exists("../consumer/bin"))
    Directory.Delete("../consumer/bin", true);
if (Directory.Exists("../consumer/obj"))
    Directory.Delete("../consumer/obj", true);
ZipFile.CreateFromDirectory("../consumer", "../consumer.zip", CompressionLevel.NoCompression, false);

var consumer_source = new BucketObject("consumer-source", new BucketObjectArgs
{
    Bucket = bucket.Name,
    Source = new FileAsset("../consumer.zip")
});
```

Additionally we need to configure the consumer function to be triggered by a pub/sub message. We can do this by specifying the `EventTrigger` property.
```csharp
var consumer_function = new Function("consumer-function", new FunctionArgs
{
    Location = region,
    BuildConfig = new FunctionBuildConfigArgs
    {
        Runtime = "dotnet6",
        EntryPoint = "Consumer.Function",
        Source = new FunctionBuildConfigSourceArgs
        {
            StorageSource = new FunctionBuildConfigSourceStorageSourceArgs
            {
                Bucket = bucket.Name,
                Object = consumer_source.Name
            }
        }
    },
    ServiceConfig = new FunctionServiceConfigArgs
    {
        EnvironmentVariables = new InputMap<string>
        {
            ["PROJECT_ID"] = project_id
        }
    },
    EventTrigger = new FunctionEventTriggerArgs
    {
        EventType = "google.cloud.pubsub.topic.v1.messagePublished",
        PubsubTopic = topic.Id,
        TriggerRegion = region,
        RetryPolicy = "RETRY_POLICY_DO_NOT_RETRY"
    }
});
```
Note the use of `EventTrigger` to specify that the function should be triggered by a pub/sub message. This will configure a pub/sub subscription for for the function to receive messages from the topic.

### Defining outputs
This is the last step in defining our infrastructure, we need to define the outputs we want to see when we run `pulumi up`. We will define the outputs for the producer and consumer endpoints.

```csharp
return new Dictionary<string, object?>
{
    ["producer_endpoint"] = producer_function.Url,
    ["consumer_endpoint"] = consumer_function.Url
};
```

### Let's take a look at the full code
```csharp
using Pulumi;
using Pulumi.Gcp.CloudFunctionsV2;
using Pulumi.Gcp.CloudFunctionsV2.Inputs;
using Pulumi.Gcp.Firestore;
using Pulumi.Gcp.PubSub;
using Pulumi.Gcp.Storage;
using System.Collections.Generic;
using System.IO.Compression;

return await Deployment.RunAsync(() =>
{
    var config = new Config();
    var region = config.Require("region");
    var gcpConfig = new Config("gcp");
    var project_id = gcpConfig.Require("project");

    // Create pubsub topic
    var topic = new Topic("sentiment-analysis");

    // Create a bucket to store the source code
    var bucket = new Bucket("function-storage-bucket", new BucketArgs
    {
        Location = "US"
    });
    
    var dataStore = new Database("(default)", new DatabaseArgs
    {
        LocationId = region,
        Type = "DATASTORE_MODE"
    }, new CustomResourceOptions
    {
        // deleting the default database will not succeed if it contains entities so we retain it
        RetainOnDelete = true,
        ImportId = "(default)"
    });    

    if (System.IO.File.Exists("../producer.zip"))
    {
        System.IO.File.Delete("../producer.zip");
    }
    
    ZipFile.CreateFromDirectory("../producer", "../producer.zip");

    // upload the producer and consumer source code to the bucket
    var producer_source = new BucketObject("producer-source", new BucketObjectArgs
    {
        Bucket = bucket.Name,
        Source = new FileAsset("../producer.zip")
    });
    var producer_function = new Function("producer-function", new FunctionArgs
    {
        Location = region,
        BuildConfig = new FunctionBuildConfigArgs
        {
            Runtime = "dotnet6",
            EntryPoint = "Producer.Function",
            Source = new FunctionBuildConfigSourceArgs
            {
                StorageSource = new FunctionBuildConfigSourceStorageSourceArgs
                {
                    Bucket = bucket.Name,
                    Object = producer_source.Name
                }
            }
        },
        ServiceConfig = new FunctionServiceConfigArgs
        {
            EnvironmentVariables = new InputMap<string>
            {
                ["PROJECT_ID"] = project_id,
                ["OUTPUT_TOPIC_ID"] = topic.Id
            }
        }
    });


    if (System.IO.File.Exists("../consumer.zip"))
    {
        System.IO.File.Delete("../consumer.zip");
    }
    ZipFile.CreateFromDirectory("../consumer", "../consumer.zip");
    var consumer_source = new BucketObject("consumer-source", new BucketObjectArgs
    {
        Bucket = bucket.Name,
        Source = new FileAsset("../consumer.zip")
    });
    var consumer_function = new Function("consumer-function", new FunctionArgs
    {
        Location = region,
        BuildConfig = new FunctionBuildConfigArgs
        {
            Runtime = "dotnet6",
            EntryPoint = "Consumer.Function",
            Source = new FunctionBuildConfigSourceArgs
            {
                StorageSource = new FunctionBuildConfigSourceStorageSourceArgs
                {
                    Bucket = bucket.Name,
                    Object = consumer_source.Name
                }
            }
        },
        ServiceConfig = new FunctionServiceConfigArgs
        {
            EnvironmentVariables = new InputMap<string>
            {
                ["PROJECT_ID"] = project_id
            }
        },
        EventTrigger = new FunctionEventTriggerArgs
        {
            EventType = "google.cloud.pubsub.topic.v1.messagePublished",
            PubsubTopic = topic.Id,
            TriggerRegion = region,
            RetryPolicy = "RETRY_POLICY_DO_NOT_RETRY"
        }
    });

    return new Dictionary<string, object?>
    {
        ["producer_endpoint"] = producer_function.Url,
        ["consumer_endpoint"] = consumer_function.Url
    };
});
```
Note: We could take a more object oriented approach to this design and create classes to share common functionality between the producer and consumer functions. This would allow us to reduce the amount of code we need to write and make it easier to maintain. However for the purposes of this demo we will keep it in a single file.

## Deploying the stack
Try running `pulumi up` to deploy changes.

You'll notice because we added required config variables to our program, pulumi will notify us that there is Missing required configuration.

Add the required configuration to your project.
```bash
pulumi config set pulumi-sentiment-analysis:region <region>
```

Notice how this is added to the `Pulumi.dev.yaml` file in the `config` section.

Run `pulumi up` again to deploy the changes.

![Pulumi Up](./images/pulumi_up.png)

Examine the details output before deploying to double check everything looks correct.
![Details](./images/details.png)

Notice how the name values of resources have a random suffix, this is to ensure the names are unique and allow multiple deployments of the same stack to exist in the same project. Pulumi will automatically generate a name based on the name we specified to Pulumi when creating the resource. 

![Implicit Resouce Naming](./images/implicit_resource_name.png)

You can override this behaviour by specifying a name explicitly in the args of the resource.

![Explicit Resouce Naming](./images/explicit_resource_name.png)

If you're happy with the changes, select `yes` to deploy the changes.
![Deployment](./images/deployment.png)

## Test the function
```bash
curl -H "Authorization: bearer $(gcloud auth print-identity-token)" --data 'My good review' <producer_endpoint>
```

## Make some changes to the application
In `producer/Function.cs` change the following line
```csharp
await context.Response.WriteAsync($"Message published to {topicName}: {messageBody}");
```
to
```csharp
await context.Response.WriteAsync($"Message published to {topicName}: {messageBody} - {DateTime.UtcNow}");
```

## Redeploy the application
```bash
pulumi up
```

## Test the function again
```bash
curl -H "Authorization: bearer $(gcloud auth print-identity-token)" --data 'My good review' <producer_endpoint>
```
Notice the response now includes a timestamp.

## Destroy the stack
```bash
pulumi down
```

## Delete the datastore db
```bash
gcloud alpha firestore databases delete --database="(default)"
```