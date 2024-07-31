using './cosmosdb.bicep'

param keyvaultName = 'docingkv'
param name = 'docingcosmosacc'
param databaseName = 'semantic_search_db'

param capabilities = [
  { name: 'EnableServerless' }
  { name: 'EnableNoSQLVectorSearch' }
]
param containers = [
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
          path: '/embedding'
          type: 'diskANN'
        }
      ]
    }
    vectorEmbeddingPolicy: {
      vectorEmbeddings: [
        {
          path: '/embedding'
          dataType: 'float32'
          distanceFunction: 'cosine'
          dimensions: 1536
        }
      ]
    }
  }
]
param secretName = 'AzureCosmosDBConnectionString'
param tags = {}
