using System.ClientModel;
using System.Net;
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

    private const int MaxRetryCount = 100;
    private const int RetryDelay = 10 * 1000; // 100 seconds

    private const int MaxBatchSize = 100;
    private int embeddingDimensions = DefaultDimensions;

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

        this.embeddingDimensions = configuration.GetValue<int>(AzureOpenAIModelDeploymentDimensionsName, DefaultDimensions);
        this._logger.LogInformation("Using OpenAI model dimensions: '{embeddingDimensions}'.", this.embeddingDimensions);

        this._logger.LogInformation("Analyzing document using DocumentAnalyzerService from blobUri: '{blobUri}' using layout: {layout}", blobClient.Name, "prebuilt-read");

        using MemoryStream memoryStream = new MemoryStream();
        await blobClient.DownloadToAsync(memoryStream);
        memoryStream.Seek(0, SeekOrigin.Begin);

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
                batchChunkTexts.Clear();
            }
        }

        // Process any remaining documents in last batch
        if (batchChunkTexts.Count > 0)
        {
            await this.ProcessCurrentBatchAsync(blobClient, cosmosDBClientWrapper, batchChunkTexts);
        }

        this._logger.LogInformation("Finished processing blob {name}, total chunks processed {count}.", blobClient.Name, totalChunksCount);
    }

    private async Task ProcessCurrentBatchAsync(BlobClient blobClient, CosmosDBClientWrapper cosmosDBClientWrapper, List<TextChunk> batchChunkTexts)
    {
        this._logger.LogInformation("Generating embeddings for : '{count}'.", batchChunkTexts.Count());
        var embeddings = await this.GenerateEmbeddingsWithRetryAsync(batchChunkTexts);

        this._logger.LogInformation("Creating Cosmos DB documents for batch of size {count}", batchChunkTexts.Count);
        await cosmosDBClientWrapper.UpsertDocumentsAsync(blobClient.Uri.AbsoluteUri, batchChunkTexts, embeddings);
    }

    private async Task<EmbeddingCollection> GenerateEmbeddingsWithRetryAsync(IEnumerable<TextChunk> batchChunkTexts)
    {
        EmbeddingGenerationOptions embeddingGenerationOptions = new EmbeddingGenerationOptions()
        {
            Dimensions = this.embeddingDimensions
        };

        int retryCount = 0;
        while (retryCount < MaxRetryCount)
        {
            try
            {
                return await embeddingClient.GenerateEmbeddingsAsync(batchChunkTexts.Select(p => p.Text).ToList(), embeddingGenerationOptions);
            }
            catch (ClientResultException ex)
            {
                if (ex.Status is ((int)HttpStatusCode.TooManyRequests) or ((int)HttpStatusCode.Unauthorized))
                {
                    if (retryCount >= MaxRetryCount)
                    {
                        throw new Exception($"Max retry attempts reached generating embeddings with exception: {ex}.");
                    }

                    retryCount++;

                    await Task.Delay(RetryDelay);
                }
                else
                {
                    throw new Exception($"Failed to generate embeddings with error: {ex}.");
                }
            }
        }

        throw new Exception($"Failed to generate embeddings after retrying for ${MaxRetryCount} times.");
    }

    private async Task HandleBlobDeleteEventAsync(BlobClient blobClient)
    {
        // TODO (amisi) - Implement me.
        this._logger.LogInformation("Handling delete event for blob name {name}.", blobClient.Name);

        await Task.Delay(1);
    }
}
