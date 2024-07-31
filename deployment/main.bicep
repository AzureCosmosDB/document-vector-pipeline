// Resource params
param tags object = {}

// Keyvault params
param keyvault_name string

// Managed identity params
param managedIdentity_name string

// Storage params
param storage_name string
param storage_containers array = []
param storage_connectionStringSecretName string

// Function app params
param function_app_name string
param function_app_storageSkuName string
param function_app_storageConnectionStringSecretName string

param function_app_storageAccountName string = '${function_app_name}store'
param function_app_appInsightsName string = '${function_app_name}insight'
param function_app_logAnalyticsName string = '${function_app_name}log'
param function_app_appServicePlanName string = '${function_app_name}service'

// CosmosDB params
param cosmosdb_capabilities array
param cosmosdb_containers array
param cosmosdb_databaseName string
param cosmosdb_secretName string
param cosmosdb_name string

// Open AI params
param open_ai_deployments array
param open_ai_name string
param open_ai_sku string
param open_ai_kind string
param open_ai_format string
param open_ai_publicNetworkAccess string

// Document intelligence params
param document_intelligence_name string
param document_intelligence_sku object
param document_intelligence_publicNetworkAccess string
param document_intelligence_disableLocalAuth bool
param documentIntelligenceEndpointKey string
@secure()
param documentIntelligenceSecretKey string

// OpenAI params
param open_ai_openAIEndpointKey string
@secure()
param open_ai_openAISecretKey string
param open_ai_openAIModelDeploymentKey string


// User managed identity resource
module userManagedIdentity_deployment 'userIdentity.bicep' = {
  name: 'userManagedIdentity_deployment'
  params: {
    managedIdentityName: managedIdentity_name
  }
}


// Keyvault resource
module keyVault_deployment 'keyvault.bicep' = {
  name: 'keyvault_deployment'
  params: {
    name: keyvault_name
    managedIdentityName: managedIdentity_name
  }
  dependsOn: [
    userManagedIdentity_deployment
  ]
}


// Storage resource
module storage_deployment 'storage.bicep' = {
  name: 'storage_deployment'
  params: {
    name: storage_name
    containers: storage_containers
    tags: tags
    keyvaultName: keyvault_name
    managedIdentityName:managedIdentity_name
    storageConnectionStringSecretName: storage_connectionStringSecretName
  }
  dependsOn: [
    userManagedIdentity_deployment
    keyVault_deployment
  ]
}


// Function App Resource
module function_app_deployment 'functionapp.bicep' = {
  name: 'function_app_deployment'
  params: {
    keyVaultName:keyvault_name
    managedIdentityName:managedIdentity_name
    functionAppName: function_app_name
    funcAppStorageSkuName: function_app_storageSkuName
    funcAppStorageAccountName: function_app_storageAccountName
    appInsightsName: function_app_appInsightsName
    appServicePlanName: function_app_appServicePlanName
    logAnalyticsName: function_app_logAnalyticsName
    funcAppStorageConnectionStringSecretName: function_app_storageConnectionStringSecretName
    storageConnectionStringSecretName: storage_connectionStringSecretName
  }
  dependsOn: [
    userManagedIdentity_deployment
    keyVault_deployment
    storage_deployment
  ]
}


// CosmosDB resource
module cosmosdb_deployment 'cosmosdb.bicep' = {
  name: 'cosmosdb_deployment'
  params: {
    capabilities: cosmosdb_capabilities
    containers: cosmosdb_containers
    databaseName: cosmosdb_databaseName
    keyvaultName: keyvault_name
    secretName: cosmosdb_secretName
    name: cosmosdb_name
    tags: tags
  }
  dependsOn: [
    userManagedIdentity_deployment
    keyVault_deployment
  ]
}


// Document Intelligence resource
module document_intelligence_deployment 'documentintelligence.bicep' = {
  name: 'document_intelligence_deployment'
  params: {
    keyvaultName: keyvault_name
    name: document_intelligence_name
    storageAccountName: storage_name
    sku: document_intelligence_sku
    publicNetworkAccess: document_intelligence_publicNetworkAccess
    disableLocalAuth: document_intelligence_disableLocalAuth
    tags: tags
    documentIntelligenceEndpointKey:documentIntelligenceEndpointKey
    documentIntelligenceSecretKey:documentIntelligenceSecretKey
  }
  dependsOn: [
    userManagedIdentity_deployment
    keyVault_deployment
    storage_deployment
  ]
}


// OpenAI Resource
module open_ai_deployment 'openai.bicep' = {
  name: 'open_ai_deployment'
  params: {
    deployments: open_ai_deployments
    managedIdentityName:managedIdentity_name
    keyvaultName: keyvault_name
    name: open_ai_name
    format: open_ai_format
    kind: open_ai_kind
    sku: open_ai_sku
    publicNetworkAccess:open_ai_publicNetworkAccess
    open_ai_openAIEndpointKey: open_ai_openAIEndpointKey
    open_ai_openAIModelDeploymentKey: open_ai_openAIModelDeploymentKey
    open_ai_openAISecretKey: open_ai_openAISecretKey
    tags: tags
  }
  dependsOn: [
    userManagedIdentity_deployment
    keyVault_deployment
  ]
}


// Output params

// User Managed Identity and KeyVault Output Params
output AZURE_USER_MANAGED_IDENTITY_NAME string = userManagedIdentity_deployment.outputs.AzureManagedIdentityName
output AZURE_KEYVAULT_NAME string = keyVault_deployment.outputs.AzureKeyVaultName
output AZURE_KEYVAULT_ENDPOINT string = keyVault_deployment.outputs.AzureKeyVaultEndpoint

// Storage Params
output AZURE_BLOB_STORE_ACCOUNT_NAME string = storage_deployment.outputs.AzureBlobStorageAccountName
output AZURE_BLOB_STORE_ACCOUNT_CONNECTION_STRING string = storage_deployment.outputs.AzureBlobStorageAccountConnectionString

// CosmosDB Params
output AZURE_COSMOS_DB_ACCOUNT_NAME string = cosmosdb_deployment.outputs.CosmosDBAccountName
output AZURE_COSMOS_DB_ENDPOINT string = cosmosdb_deployment.outputs.CosmosDBEndpoint
output AZURE_COSMOS_DB_SECRET_NAME string = cosmosdb_deployment.outputs.CosmosDBKeySecretName
output AZURE_COSMOS_DB_KEYVAULT_REFERNCE string = cosmosdb_deployment.outputs.CosmosDBKeyVaultReference

// Document Intelligence Params
output AZURE_DOCUMENT_INTELLIGENCE_NAME string = document_intelligence_deployment.outputs.DocumentIntelligenceName
output AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT string = document_intelligence_deployment.outputs.DocumentIntelligenceEndpoint
output AZURE_DOCUMENT_INTELLIGENCE_HOST string = document_intelligence_deployment.outputs.DocumentIntelligenceHost

// OpenAI
output AZURE_OPEN_AI_SERVICE_NAME string = open_ai_deployment.outputs.openAIServiceName
output AZURE_OPEN_AI_SERVICE_ENDPOINT string = open_ai_deployment.outputs.openAIServiceEndpoint
output AZURE_OPEN_AI_KEY_SECRET_NAME string = open_ai_deployment.outputs.keySecretName
output AZURE_OPEN_AI_KEY_SECRET_VALUE string = open_ai_deployment.outputs.keySecretValue
