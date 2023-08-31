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