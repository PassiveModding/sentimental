using Google.Cloud.Functions.Framework;
using Microsoft.AspNetCore.Http;
using Google.Cloud.PubSub.V1;
using Microsoft.Extensions.Logging;
using Google.Cloud.Functions.Hosting;

namespace Producer;

/**
 * This function is triggered by an HTTP request and publishes a message to a Pub/Sub topic.
 * The message body is expected to be a string.
 */
[FunctionsStartup(typeof(Startup))]
public class Function : IHttpFunction
{
    private readonly ILogger<Function> _logger;
    private readonly PublisherClient publisherClient;
    private readonly PublisherConfig config;

    public Function(ILogger<Function> logger, PublisherClient publisherClient, PublisherConfig config)
    {
        _logger = logger;
        this.publisherClient = publisherClient;
        this.config = config;
    }

    public async Task HandleAsync(HttpContext context)
    {
        // Get the message body from the request
        using var reader = new StreamReader(context.Request.Body);
        var messageBody = await reader.ReadToEndAsync();       
        await publisherClient.PublishAsync(new PubsubMessage
        {
            Data = Google.Protobuf.ByteString.CopyFromUtf8(messageBody)
        });

        _logger.LogInformation("Message published to {output_topic}: {messageBody}", config.topic, messageBody);

        context.Response.StatusCode = StatusCodes.Status200OK;
        await context.Response.WriteAsync($"Message published to {config.topic}: {messageBody}");
    }
}
