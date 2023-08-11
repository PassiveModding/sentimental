using Google.Cloud.Functions.Hosting;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Configuration;
using Google.Cloud.PubSub.V1;
using Google.Cloud.Datastore.V1;
using Grpc.Core;

namespace Consumer;

public class Startup : FunctionsStartup
{
    public override void ConfigureServices(WebHostBuilderContext context, IServiceCollection services)
    {
        var pubsubEmulatorHost = Environment.GetEnvironmentVariable("PUBSUB_EMULATOR_HOST");  
        var datastoreEmulatorHost = Environment.GetEnvironmentVariable("DATASTORE_EMULATOR_HOST");   
        
        var project_id = Environment.GetEnvironmentVariable("PROJECT_ID") ?? throw new Exception("PROJECT_ID not set");
               
        if (!string.IsNullOrEmpty(pubsubEmulatorHost) && !string.IsNullOrEmpty(datastoreEmulatorHost))
        {
            Task.Delay(5000).Wait();
            var input_topic = Environment.GetEnvironmentVariable("INPUT_TOPIC") ?? throw new Exception("INPUT_TOPIC not set");
            var push_endpoint = Environment.GetEnvironmentVariable("PUSH_ENDPOINT") ?? throw new Exception("PUSH_ENDPOINT not set");
            var topicName = new TopicName(project_id, input_topic);
            CreateSubscription(pubsubEmulatorHost, project_id, topicName, push_endpoint);
            services.AddSingleton<ILanguageService, LanguageServiceMock>();
            services.AddSingleton(new DatastoreDbBuilder()
            {
                Endpoint = datastoreEmulatorHost,
                ChannelCredentials = ChannelCredentials.Insecure,
                ProjectId = project_id
            }.Build());
        }
        else
        {
            services.AddSingleton<ILanguageService, LanguageService>();
            services.AddSingleton(DatastoreDb.Create(project_id));
        }
    }

    private void CreateSubscription(string emulatorHost, string project_id, TopicName topicName, string push_endpoint)
    {
        var subscriber = new SubscriberServiceApiClientBuilder()
        {
            Endpoint = emulatorHost,
            ChannelCredentials = ChannelCredentials.Insecure
        }.Build();
            

        subscriber.CreateSubscription(new SubscriptionName(project_id, "test-sub"), 
        topicName, pushConfig: new PushConfig
        {
            PushEndpoint = push_endpoint
        }, ackDeadlineSeconds: 60);
    }
}