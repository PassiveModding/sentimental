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
