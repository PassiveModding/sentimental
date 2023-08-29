using CloudNative.CloudEvents;
using Google.Cloud.Datastore.V1;
using Google.Cloud.Functions.Framework;
using Google.Cloud.Functions.Hosting;
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

        DatastoreDb db;
        try
        {
            var projectId = Environment.GetEnvironmentVariable("PROJECT_ID") ?? throw new Exception("PROJECT_ID not set");
            db = DatastoreDb.Create(projectId);
        }
        catch (Exception ex)
        {
            _logger.LogError("Error creating datastore client: {error}", ex.Message);
            throw;
        }

        float sentiment;
        try
        {
            var client = await LanguageServiceClient.CreateAsync(cancellationToken);
            var sentimentResult = await client.AnalyzeSentimentAsync(new Document()
            {
                Content = data.Message.TextData,
                Type = Document.Types.Type.PlainText
            }, cancellationToken);   
            sentiment = sentimentResult.DocumentSentiment.Score;        
        }
        catch (Exception ex)
        {
            _logger.LogError("Error getting sentiment: {error}", ex.Message);
            throw;
        }

        _logger.LogInformation("Sentiment score: {score}", sentiment);
        KeyFactory keyFactory;
        
        try 
        {
            keyFactory = db.CreateKeyFactory("sentiment");
        }
        catch (Exception ex)
        {
            _logger.LogError("Error creating key factory: {error}", ex.Message);
            throw;
        }

        try
        {
            Google.Cloud.Datastore.V1.Entity entity = new()
            {
                Key = keyFactory.CreateIncompleteKey(),
                ["created"] = DateTime.UtcNow,
                ["text"] = data.Message.TextData,
                ["score"] = sentiment
            };
            using var transaction = await db.BeginTransactionAsync();
            transaction.Insert(entity);
            CommitResponse commitResponse = await transaction.CommitAsync();
            Key insertedKey = commitResponse.MutationResults[0].Key;
            _logger.LogInformation("Inserted key: {key}", insertedKey);
        }
        catch (Exception ex)
        {
            _logger.LogError("Error inserting entity: {error}", ex.Message);
            throw;
        }
    }
}
