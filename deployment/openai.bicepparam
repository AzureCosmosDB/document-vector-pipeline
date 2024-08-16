using './openai.bicep'

param managedIdentityName = 'docinguseridentity'
param keyvaultName = 'docingkv'
param name = 'docingopenaiacc'
param embeddingModelName = 'text-embedding-3-large'
param embeddingModelDimensions = '1536'

param deployments = [
  {
    name: embeddingModelName
    sku: {
      name: 'Standard'
      capacity: 200
    }
    model: {
      name: embeddingModelName
      version: '1'
    }
  }
]
param sku = 'S0'
param kind = 'OpenAI'
param format = 'OpenAI'
param publicNetworkAccess = 'Enabled'
param open_ai_openAIEndpointKey = 'AzureOpenAIEndpoint'
param open_ai_openAISecretKey = 'AzureOpenAIApiKey'
param open_ai_openAIModelDeploymentKey = 'AzureOpenAIModelDeployment'
param open_ai_openAIModelDimensionsKey = 'AzureOpenAIModelDimensions'
param tags =  {}
