using CloudNative.CloudEvents;
using Google.Cloud.Datastore.V1;
using Google.Cloud.Functions.Framework;
using Google.Cloud.Functions.Hosting;
using Google.Events.Protobuf.Cloud.PubSub.V1;
using Microsoft.Extensions.Logging;

namespace Consumer;

[FunctionsStartup(typeof(Startup))]
public class Function : ICloudEventFunction<MessagePublishedData>
{
    
    private readonly ILogger<Function> _logger;
    private readonly ILanguageService languageService;
    private readonly DatastoreDb datastore;

    public Function(ILogger<Function> logger, ILanguageService languageService, DatastoreDb datastore)
    {
        _logger = logger;
        this.languageService = languageService;
        this.datastore = datastore;
    }

    public async Task HandleAsync(CloudEvent cloudEvent, MessagePublishedData data, CancellationToken cancellationToken)
    {
        _logger.LogInformation("Received Pub/Sub message with data: {data}", data.Message.TextData);
        
        var sentiment = await languageService.GetSentimentAsync(data.Message.TextData, cancellationToken);

        _logger.LogInformation("Sentiment score: {score}", sentiment);

        KeyFactory keyFactory = datastore.CreateKeyFactory("sentiment");
        Entity entity = new Entity
        {
            Key = keyFactory.CreateIncompleteKey(),
            ["created"] = DateTime.UtcNow,
            ["text"] = data.Message.TextData,
            ["score"] = sentiment
        };
        using var transaction = await datastore.BeginTransactionAsync();
        transaction.Insert(entity);
        CommitResponse commitResponse = await transaction.CommitAsync();
        Key insertedKey = commitResponse.MutationResults[0].Key;
        _logger.LogInformation("Inserted key: {key}", insertedKey);
    }
}
