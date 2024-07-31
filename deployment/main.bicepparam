using './main.bicep'


// Common params
param tags = {}

var baseName = 'docing'

// Naming params
param managedIdentity_name = '${baseName}useridentity'
param keyvault_name = '${baseName}kv'
param storage_name = '${baseName}blobacc'
param function_app_name = '${baseName}funcapp'
param cosmosdb_name = '${baseName}cosmosacc'
param document_intelligence_name = '${baseName}docintl'
param open_ai_name = '${baseName}openai'

// User assigned identity parameters

// Storage params
param storage_containers = [
  {
    name: 'documents'
  }
]
param storage_connectionStringSecretName = 'StorageAccountConnectionString'


// Function app params
param function_app_storageSkuName = 'Standard_LRS'
param function_app_storageConnectionStringSecretName = 'AzureWebJobsStorageConnectionString'


// CosmosDB params
param cosmosdb_databaseName = 'semantic_search_db'
param cosmosdb_capabilities = [
  { name: 'EnableServerless' }
]
param cosmosdb_containers = [
  {
    name: 'doc_search_container'
    partitionKeyPath: '/document_url'
    indexingPolicy: {
      indexingMode: 'consistent'
      automatic: true
      includedPaths: [
        {
          path:'/*'
        }
      ]
      fullTextIndexes: [
        {
          path: '/content'
          language: 1033
        }
      ]
      vectorIndexes: [
        {
          path: '/embeddings'
          type: 'diskANN'
        }
      ]
    }
    vectorEmbeddingPolicy: {
      vectorEmbeddings: [
        {
          path: '/embeddings'
          dataType: 'float32'
          distanceFunction: 'cosine'
          dimensions: 1536
        }
      ]
    }
  }
]
param cosmosdb_secretName = 'AzureCosmosDBConnectionString'


// Document Intelligence Params
param document_intelligence_sku = {
  name: 'S0'
}
param document_intelligence_publicNetworkAccess = 'Enabled'
param document_intelligence_disableLocalAuth = false
param documentIntelligenceEndpointKey = 'AzureDocumentIntelligenceEndpoint'
param documentIntelligenceSecretKey = 'AzureDocumentIntelligenceApiKey'


// Open AI params
param open_ai_deployments = [
  {
    name: 'ada'
    sku: {
      name: 'Standard'
      capacity: 50
    }
    model: {
      name: 'text-embedding-ada-002'
      version: '2'
    }
  }
]
param open_ai_sku = 'S0'
param open_ai_kind = 'OpenAI'
param open_ai_format = 'OpenAI'
param open_ai_publicNetworkAccess = 'Enabled'
param open_ai_openAIEndpointKey = 'AzureOpenAIEndpoint'
param open_ai_openAISecretKey = 'AzureOpenAIApiKey'
param open_ai_openAIModelDeploymentKey = 'AzureOpenAIModelDeployment'
