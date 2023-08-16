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
        var datastoreEmulatorHost = Environment.GetEnvironmentVariable("DATASTORE_EMULATOR_HOST");   
        
        var project_id = Environment.GetEnvironmentVariable("PROJECT_ID") ?? throw new Exception("PROJECT_ID not set");
               
        if (!string.IsNullOrEmpty(datastoreEmulatorHost))
        {
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
}