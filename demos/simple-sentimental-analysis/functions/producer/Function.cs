using Google.Cloud.Functions.Framework;
using Microsoft.AspNetCore.Http;
using Google.Cloud.PubSub.V1;
using Microsoft.Extensions.Logging;

namespace Producer;

/**
 * This function is triggered by an HTTP request and publishes a message to a Pub/Sub topic.
 * The message body is expected to be a string.
 */
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
