using Pulumi;
using Pulumi.Gcp.CloudFunctionsV2;
using Pulumi.Gcp.CloudFunctionsV2.Inputs;
using Pulumi.Gcp.Firestore;
using Pulumi.Gcp.PubSub;
using Pulumi.Gcp.Storage;
using System.Collections.Generic;
using System.IO.Compression;
using System.IO;

return await Deployment.RunAsync(() =>
{
    var config = new Config();
    var region = config.Require("region");
    var gcpConfig = new Config("gcp");
    var projectId = gcpConfig.Require("project");

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
                ["PROJECT_ID"] = projectId,
                ["OUTPUT_TOPIC_ID"] = topic.Id
            }
        }
    });
    
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
                ["PROJECT_ID"] = projectId
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
