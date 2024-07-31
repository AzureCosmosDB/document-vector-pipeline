using './openai.bicep'

param managedIdentityName = 'docinguseridentity'
param keyvaultName = 'docingkv'
param name = 'docingopenaiacc'

param deployments = [
  {
    name: 'ada'
    sku: {
      name: 'Standard'
      capacity: 200
    }
    model: {
      name: 'text-embedding-ada-002'
      version: '2'
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
param tags =  {}
