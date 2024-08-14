param location string = resourceGroup().location

// Input parameters
param containers array = []
param keyvaultName string
param name string
param tags object
param storageConnectionStringSecretName string

// Create storage account
resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: name
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  tags: tags
}

// Connection string to storage account
var storageConnectionStringValue = 'DefaultEndpointsProtocol=https;AccountName=${name};AccountKey=${storage.listKeys().keys[0].value};EndpointSuffix=core.windows.net'


// Create storage containers
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storage
  name: 'default'
}

resource blobContainers 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = [
  for container in containers: {
    parent: blobService
    name: container.name
  }
]


// Assign user identity permissions to storage account
param managedIdentityName string
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing= {
  name: managedIdentityName
}

param storage_account_id_roles array = ['b24988ac-6180-42a0-ab88-20f7382dd24c','ba92f5b4-2d11-453d-a403-e96b0029c9fe'] // Contributor, Storage blob data contributor
resource roleAssignmentFuncStorageAccount 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = [for id_role in storage_account_id_roles : {
  name: guid(resourceGroup().id, '${storage.name}-storagerole', id_role)
  scope: blobService
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', id_role)
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
  }
]


// Persist storage connection string to keyvault
resource keyvault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: keyvaultName
}

resource storageConnectionString 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  name: storageConnectionStringSecretName
  parent: keyvault
  tags: tags
  properties: {
    value: storageConnectionStringValue
  }
}


// Output storage account name, connection string and key
output AzureBlobStorageAccountName string = storage.name
output AzureBlobStorageAccountConnectionString string = storageConnectionString.name
output AzureBlobStorageAccountSecretValue string = storageConnectionString.properties.secretUri
