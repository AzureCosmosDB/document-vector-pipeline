using './documentintelligence.bicep'

param keyvaultName = 'docingkv'
param name = 'docingdocintl'
param storageAccountName = 'docingblobacc'

param tags = {}
param sku = {
  name: 'S0'
}
param publicNetworkAccess = 'Enabled'
param disableLocalAuth = false
param documentIntelligenceEndpointKey = 'AzureDocumentIntelligenceEndpoint'
param documentIntelligenceSecretKey = 'AzureDocumentIntelligenceApiKey'
