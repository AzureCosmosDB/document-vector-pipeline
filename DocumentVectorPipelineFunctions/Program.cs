using System.ClientModel.Primitives;
using System.Text.Json;
using Azure;
using Azure.AI.FormRecognizer.DocumentAnalysis;
using Azure.AI.OpenAI;
using Azure.Core;
using Azure.Core.Pipeline;
using Azure.Identity;
using BlobStorageTriggeredFunction;
using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using OpenAI.Embeddings;

const string AzureDocumentIntelligenceEndpointConfigName = "AzureDocumentIntelligenceEndpoint";
const string AzureDocumentIntelligenceApiKeyConfigName = "AzureDocumentIntelligenceApiKey";
const string AzureCosmosDBConnectionStringConfigName = "AzureCosmosDBConnectionString";
const string AzureOpenAIEndpointConfigName = "AzureOpenAIEndpoint";
const string AzureOpenAIApiKeyConfigName = "AzureOpenAIApiKey";
const string AzureOpenAIModelDeploymentConfigName = "AzureOpenAIModelDeployment";

string? keyVaultUri = Environment.GetEnvironmentVariable("AzureKeyVaultEndpoint");
if (string.IsNullOrWhiteSpace(keyVaultUri))
{
    throw new InvalidOperationException("Set environment variable 'AzureKeyVaultEndpoint' to run.");
}

string? managedIdentityClientId = Environment.GetEnvironmentVariable("AzureManagedIdentityClientId");
bool local = Convert.ToBoolean(Environment.GetEnvironmentVariable("RunningLocally"));

var hostBuilder = new HostBuilder()
    .ConfigureFunctionsWorkerDefaults()
    .ConfigureAppConfiguration(config =>
    {
        TokenCredential credential = local
            ? new DefaultAzureCredential()
            : new ManagedIdentityCredential(clientId: managedIdentityClientId);

        config.AddAzureKeyVault(new Uri(keyVaultUri), credential);
        config.AddUserSecrets<BlobTriggerFunction>(optional: true, reloadOnChange: false);
    });

hostBuilder.ConfigureServices(sc =>
{
    sc.AddSingleton<DocumentAnalysisClient>(sp =>
    {
        var config = sp.GetRequiredService<IConfiguration>();
        var documentAnalysisClient = new DocumentAnalysisClient(
            new Uri(config[AzureDocumentIntelligenceEndpointConfigName] ?? throw new Exception($"Configure {AzureDocumentIntelligenceEndpointConfigName}")),
            new AzureKeyCredential(config[AzureDocumentIntelligenceApiKeyConfigName] ?? throw new Exception($"Configure {AzureDocumentIntelligenceApiKeyConfigName}")));
        return documentAnalysisClient;
    });
    sc.AddSingleton<CosmosClient>(sp =>
    {
        var config = sp.GetRequiredService<IConfiguration>();
        var cosmosClient = new CosmosClient(
            config[AzureCosmosDBConnectionStringConfigName] ?? throw new Exception($"Configure {AzureCosmosDBConnectionStringConfigName}"),
            new CosmosClientOptions
            {
                ApplicationName = "document ingestion",
                AllowBulkExecution = true,
                Serializer = new CosmosSystemTextJsonSerializer(JsonSerializerOptions.Default),
            });
        return cosmosClient;
    });
    sc.AddSingleton<EmbeddingClient>(sp =>
    {
        var config = sp.GetRequiredService<IConfiguration>();
        // TODO: Implement a custom retry policy that takes the retry-after header into account.
        var options = new AzureOpenAIClientOptions()
        {
            ApplicationId = "DocumentIngestion",
            RetryPolicy = new ClientRetryPolicy(maxRetries: 10),
        };
        var azureOpenAIClient = new AzureOpenAIClient(
            new Uri(config[AzureOpenAIEndpointConfigName] ?? throw new Exception($"Configure {AzureOpenAIEndpointConfigName}")),
            new AzureKeyCredential(config[AzureOpenAIApiKeyConfigName] ?? throw new Exception($"Configure {AzureOpenAIApiKeyConfigName}")),
            options);
        return azureOpenAIClient.GetEmbeddingClient(config[AzureOpenAIModelDeploymentConfigName] ?? throw new Exception($"Configure {AzureOpenAIModelDeploymentConfigName}"));
    });
});

var host = hostBuilder.Build();
host.Run();
