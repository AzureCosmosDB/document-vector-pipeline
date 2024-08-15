using Azure;
using Azure.AI.FormRecognizer.DocumentAnalysis;
using Azure.Storage.Blobs;
using Microsoft.Azure.Cosmos;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using OpenAI.Embeddings;

namespace BlobStorageTriggeredFunction;

public class BlobTriggerFunction(
    IConfiguration configuration,
    DocumentAnalysisClient documentAnalysisClient,
    ILoggerFactory loggerFactory,
    CosmosClient cosmosClient,
    EmbeddingClient embeddingClient)
{
    private readonly ILogger _logger = loggerFactory.CreateLogger<BlobTriggerFunction>();

    private const string AzureOpenAIModelDeploymentDimensionsName = "AzureOpenAIModelDimensions";
    private static readonly int DefaultDimensions = 1536;

    private const int MaxBatchSize = 2048;

    [Function("BlobTriggerFunction")]
    public async Task Run([BlobTrigger("documents/{name}", Connection = "AzureBlobStorageAccConnectionString")] BlobClient blobClient)
    {
        this._logger.LogInformation("Starting processing of blob name: '{name}'", blobClient.Name);

        if (await blobClient.ExistsAsync())
        {
            await this.HandleBlobCreateEventAsync(blobClient);
        }
        else
        {
            await this.HandleBlobDeleteEventAsync(blobClient);
        }
        this._logger.LogInformation("Finished processing of blob name: '{name}'", blobClient.Name);
    }

    private async Task HandleBlobCreateEventAsync(BlobClient blobClient)
    {
        this._logger.LogInformation("Analyzing document using DocumentAnalyzerService from blobUri: '{blobUri}' using layout: {layout}", blobClient.Name, "prebuilt-read");
        var operation = await documentAnalysisClient.AnalyzeDocumentFromUriAsync(
            WaitUntil.Completed,
            "prebuilt-read",
            blobClient.Uri);

        var result = operation.Value;

        this._logger.LogInformation("Extracted content from '{name}', # pages {pageCount}", blobClient.Name, result.Pages.Count);

        var cosmosDBClientWrapper = await CosmosDBClientWrapper.CreateInstance(cosmosClient, this._logger);

        int totalChunksCount = 0;
        var batchChunkTexts = new List<TextChunk>();
        foreach (var chunk in TextChunker.FixedSizeChunking(result))
        {
            batchChunkTexts.Add(chunk);
            totalChunksCount++;

            if (batchChunkTexts.Count >= MaxBatchSize)
            {
                await this.ProcessCurrentBatchAsync(blobClient, cosmosDBClientWrapper, batchChunkTexts);
            }
        }

        // Process any remaining documents in last batch
        if (batchChunkTexts.Count > 0)
        {
            await this.ProcessCurrentBatchAsync(blobClient, cosmosDBClientWrapper, batchChunkTexts);
        }

        this._logger.LogInformation("Created total chunks: '{documentCount}' of document.", totalChunksCount);
    }

    private async Task ProcessCurrentBatchAsync(BlobClient blobClient, CosmosDBClientWrapper cosmosDBClientWrapper, List<TextChunk> batchChunkTexts)
    {
        this._logger.LogInformation("Creating Cosmos DB documents for batch of size {count}", batchChunkTexts.Count);

        int embeddingDimensions = DefaultDimensions;
        if (configuration != null &&
            !string.IsNullOrWhiteSpace(configuration[AzureOpenAIModelDeploymentDimensionsName]) &&
            int.TryParse(configuration[AzureOpenAIModelDeploymentDimensionsName], out int inputDimensions))
        {
            embeddingDimensions = inputDimensions;
            this._logger.LogInformation("Using OpenAI model dimensions: '{embeddingDimensions}'.", embeddingDimensions);
        }

        EmbeddingGenerationOptions embeddingGenerationOptions = new EmbeddingGenerationOptions()
        {
            Dimensions = embeddingDimensions
        };
        var embeddings = await embeddingClient.GenerateEmbeddingsAsync(batchChunkTexts.Select(p => p.Text).ToList(), embeddingGenerationOptions);
        await cosmosDBClientWrapper.UpsertDocumentsAsync(blobClient.Uri.AbsoluteUri, batchChunkTexts, embeddings);

        batchChunkTexts.Clear();
    }

    private async Task HandleBlobDeleteEventAsync(BlobClient blobClient)
    {
        // TODO (amisi) - Implement me.
        this._logger.LogInformation("Handling delete event for blob name {name}.", blobClient.Name);

        await Task.Delay(1);
    }
}

