using System.ClientModel.Primitives;
using System.Text.Json;
using Azure.AI.FormRecognizer.DocumentAnalysis;
using Azure.AI.OpenAI;
using Azure.Core;
using Azure.Identity;
using DocumentVectorPipelineFunctions;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using OpenAI.Embeddings;

const string AzureDocumentIntelligenceEndpointConfigName = "AzureDocumentIntelligenceConnectionString";
//const string AzureCosmosDBConnectionString = "AzureCosmosDBConnectionString";
const string AzureOpenAIConnectionString = "AzureOpenAIConnectionString";
const string AzureOpenAIModelDeploymentConfigName = "AzureOpenAIModelDeployment";
const string AzureDocumentIntelligenceKey = "AzureDocumentIntelligenceKey";
const string AzureOpenAIKey = "AzureOpenAIKey";

string? managedIdentityClientId = Environment.GetEnvironmentVariable("AzureManagedIdentityClientId");
bool local = Convert.ToBoolean(Environment.GetEnvironmentVariable("RunningLocally"));

Console.WriteLine($"Running locally: {local}");

TokenCredential credential = local
    ? new DefaultAzureCredential()
    : new ManagedIdentityCredential(clientId: managedIdentityClientId);

var hostBuilder = new HostBuilder()
    .ConfigureFunctionsWorkerDefaults()
    .ConfigureAppConfiguration(config =>
    {
        config.AddUserSecrets<BlobTriggerFunction>(optional: true, reloadOnChange: false);
    });

hostBuilder.ConfigureServices(sc =>
{
    sc.AddSingleton<DocumentAnalysisClient>(sp =>
    {
        var config = sp.GetRequiredService<IConfiguration>();
        var docaiKey = config[AzureDocumentIntelligenceKey] ?? throw new Exception($"Configure {AzureDocumentIntelligenceKey}");
        var documentIntelligenceEndpoint = config[AzureDocumentIntelligenceEndpointConfigName] ?? throw new Exception($"Configure {AzureDocumentIntelligenceEndpointConfigName}");
        var documentAnalysisClient = new DocumentAnalysisClient(
            new Uri(documentIntelligenceEndpoint),
            new Azure.AzureKeyCredential(docaiKey));
        return documentAnalysisClient;
    });
    //sc.AddSingleton<CosmosClient>(sp =>
    //{
    //    var config = sp.GetRequiredService<IConfiguration>();
    //    var cosmosdbEndpoint = config[AzureCosmosDBConnectionString] ?? throw new Exception($"Configure {AzureCosmosDBConnectionString}");
    //    var cosmosClient = new CosmosClient(
    //        cosmosdbEndpoint,
    //        credential,
    //        new CosmosClientOptions
    //        {
    //            ApplicationName = "document ingestion",
    //            AllowBulkExecution = true,
    //            Serializer = new CosmosSystemTextJsonSerializer(JsonSerializerOptions.Default),
    //        });
    //    return cosmosClient;
    //});
    sc.AddSingleton<EmbeddingClient>(sp =>
    {
        var config = sp.GetRequiredService<IConfiguration>();
        var openAIEndpoint = config[AzureOpenAIConnectionString] ?? throw new Exception($"Configure {AzureOpenAIConnectionString}");
        var azureAIKey = config[AzureOpenAIKey] ?? throw new Exception($"Configure {AzureOpenAIKey}");

        // TODO: Implement a custom retry policy that takes the retry-after header into account.
        var azureOpenAIClient = new AzureOpenAIClient(
            new Uri(openAIEndpoint),
            new Azure.AzureKeyCredential(azureAIKey),
            new AzureOpenAIClientOptions()
            {
                ApplicationId = "DocumentIngestion",
                RetryPolicy = new ClientRetryPolicy(maxRetries: 10),
            });
        return azureOpenAIClient.GetEmbeddingClient(config[AzureOpenAIModelDeploymentConfigName] ?? throw new Exception($"Configure {AzureOpenAIModelDeploymentConfigName}"));
    });
});

var host = hostBuilder.Build();
host.Run();
