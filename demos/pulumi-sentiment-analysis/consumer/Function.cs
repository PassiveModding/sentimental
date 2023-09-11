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
