@description('Location to deploy the resource. Defaults to the location of the resource group.')
param location string = resourceGroup().location


// Input parameters
param name string
param tags object
param sku object
param publicNetworkAccess string
param disableLocalAuth bool

param documentIntelligenceEndpointKey string
@secure()
param documentIntelligenceSecretKey string


// Get existing storage account for assign permissions
param storageAccountName string
resource storage_account 'Microsoft.Storage/storageAccounts@2021-06-01' existing = {
  name: storageAccountName
}


// Get existing keyvault resource
param keyvaultName string
resource keyvault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: keyvaultName
}

// Create document intelligence resource
resource documentIntelligence 'Microsoft.CognitiveServices/accounts@2023-10-01-preview' = {
  name: name
  location: location
  tags: tags
  kind: 'FormRecognizer'
  // Todo(amisi) - DI only supports systemindentity as of now. Need to move to userassignedidentity when supported.
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    disableLocalAuth: disableLocalAuth
    publicNetworkAccess: publicNetworkAccess
    networkAcls: {
      defaultAction: 'Allow'
      ipRules: []
      virtualNetworkRules: []
    }
  }
  sku: sku
}
var connectionKey = documentIntelligence.listKeys().key1


// Assign storage account contributor role to func_app_storage_account
param storage_account_id_roles array = ['ba92f5b4-2d11-453d-a403-e96b0029c9fe'] // Storage blob data contributor
resource roleAssignmentFuncStorageAccount 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = [for id_role in storage_account_id_roles : {
  name: guid(resourceGroup().id, '${name}-docintlrole', id_role)
  scope: storage_account
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', id_role)
    principalId: documentIntelligence.identity.principalId
    principalType: 'ServicePrincipal'
  }
  }
]


// Update document intelligence acc secrets to keyvault.
resource documentIntlEndpoint 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  name: documentIntelligenceEndpointKey
  parent: keyvault
  tags: tags
  properties: {
    value: documentIntelligence.properties.endpoint
  }
}
resource documentIntlConnStr 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  name: documentIntelligenceSecretKey
  parent: keyvault
  tags: tags
  properties: {
    value: connectionKey
  }
}


// Output parameters
@description('Name for the deployed Document Intelligence resource.')
output DocumentIntelligenceName string = documentIntelligence.name

@description('Endpoint for the deployed Document Intelligence resource.')
output DocumentIntelligenceEndpoint string = documentIntelligence.properties.endpoint

@description('Host for the deployed Document Intelligence resource.')
output DocumentIntelligenceHost string = split(documentIntelligence.properties.endpoint, '/')[2]

@description('Key for document intelligence resource.')
output DocumentIntelligenceKey string = connectionKey
