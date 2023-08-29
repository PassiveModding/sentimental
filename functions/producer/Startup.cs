using Google.Cloud.Functions.Hosting;
using Google.Cloud.PubSub.V1;
using Grpc.Core;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.DependencyInjection;

namespace Producer;

public class Startup : FunctionsStartup
{
    public override void ConfigureServices(WebHostBuilderContext context, IServiceCollection services)
    {
        // if pubsub emulator is configured, use it
        var emulatorHost = Environment.GetEnvironmentVariable("PUBSUB_EMULATOR_HOST");
        var output_topic_id = Environment.GetEnvironmentVariable("OUTPUT_TOPIC_ID") ?? throw new Exception("OUTPUT_TOPIC_ID not set");
        var project_id = Environment.GetEnvironmentVariable("PROJECT_ID") ?? throw new Exception("PROJECT_ID not set");
        // get the topic name from the full topic id
        var topicName = new TopicName(project_id, output_topic_id.Split('/').Last());
        
        if (!string.IsNullOrEmpty(emulatorHost))
        {
            var client = new PublisherClientBuilder
            {
                Endpoint = emulatorHost,
                ChannelCredentials = ChannelCredentials.Insecure,
                TopicName = topicName          
            }.Build();     
            services.AddSingleton(client);       
        }
        else
        {
            services.AddSingleton(PublisherClient.Create(topicName));
        }

        services.AddSingleton(new PublisherConfig(topicName));
    }
}

public class PublisherConfig
{
    public TopicName topic;

    public PublisherConfig(TopicName topic)
    {
        this.topic = topic;
    }
}
