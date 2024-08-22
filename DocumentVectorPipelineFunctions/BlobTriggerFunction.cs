using Azure;
using Azure.AI.FormRecognizer.DocumentAnalysis;
using Azure.Storage.Blobs;
using Microsoft.Azure.Cosmos;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using OpenAI.Embeddings;

namespace DocumentVectorPipelineFunctions;

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
    private static readonly int BufferSize = 4 * 1024 * 1024; // 4MB

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
        var cosmosDBClientWrapper = await CosmosDBClientWrapper.CreateInstance(cosmosClient, this._logger);

        this._logger.LogInformation("Analyzing document using DocumentAnalyzerService from blobUri: '{blobUri}' using layout: {layout}", blobClient.Name, "prebuilt-read");

        MemoryStream memoryStream = new MemoryStream();
        await blobClient.DownloadToAsync(memoryStream);

        var operation = await documentAnalysisClient.AnalyzeDocumentAsync(
            WaitUntil.Completed,
            "prebuilt-read",
            memoryStream);

        var result = operation.Value;
        this._logger.LogInformation("Extracted content from '{name}', # pages {pageCount}", blobClient.Name, result.Pages.Count);

        int totalChunksCount = 0;
        var batchChunkTexts = new List<TextChunk>(MaxBatchSize);
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

        this._logger.LogInformation("Finished processing blob {0}, total chunks processed {1}.", blobClient.Name, totalChunksCount);
    }

    private async Task ProcessCurrentBatchAsync(BlobClient blobClient, CosmosDBClientWrapper cosmosDBClientWrapper, List<TextChunk> batchChunkTexts)
    {
        this._logger.LogInformation("Creating Cosmos DB documents for batch of size {count}", batchChunkTexts.Count);

        int embeddingDimensions = configuration.GetValue<int>(AzureOpenAIModelDeploymentDimensionsName, DefaultDimensions);
        this._logger.LogInformation("Using OpenAI model dimensions: '{embeddingDimensions}'.", embeddingDimensions);

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
