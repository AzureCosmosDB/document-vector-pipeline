param location string= resourceGroup().location

// Input parameters
param deployments array
param keyvaultName string
param name string
param sku string
param tags object
param kind string
param format string
param publicNetworkAccess string
param open_ai_openAIEndpointKey string
@secure()
param open_ai_openAISecretKey string
param open_ai_openAIModelDeploymentKey string
param open_ai_openAIModelDimensionsKey string
param embeddingModelName string
param embeddingModelDimensions string

// Get existing keyvault resource
resource keyvault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: keyvaultName
}


// Create openAI resource
resource openAi 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: name
  location: location
  sku: {
    name: sku
  }
  kind: kind
  properties: {
    publicNetworkAccess: publicNetworkAccess
  }
  tags: tags
}

@batchSize(1)
resource openAiDeployments 'Microsoft.CognitiveServices/accounts/deployments@2024-04-01-preview' = [
  for deployment in deployments: {
    parent: openAi
    name: deployment.name
    sku: {
      capacity: deployment.sku.capacity
      name: deployment.sku.name
    }
    properties: {
      model: {
        format: format
        name: deployment.model.name
        version: deployment.model.version
      }
    }
  }
]


// Assign user managed identity to openai app.
param managedIdentityName string
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing= {
  name: managedIdentityName
}
param storage_account_id_roles array = ['b24988ac-6180-42a0-ab88-20f7382dd24c'] // contributor
resource roleAssignmentFuncStorageAccount 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = [for id_role in storage_account_id_roles : {
  name: guid(resourceGroup().id, '${name}-openairole', id_role)
  scope: openAi
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', id_role)
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
  }
]


// Persist OpenAI secrets to keyvault.
resource openAIEndpoint 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  name: open_ai_openAIEndpointKey
  parent: keyvault
  tags: tags
  properties: {
    value: openAi.properties.endpoint
  }
}
resource openAIModelDeployment 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  name: open_ai_openAIModelDeploymentKey
  parent: keyvault
  tags: tags
  properties: {
    value: embeddingModelName
  }
}
resource openAIModelDimensions 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  name: open_ai_openAIModelDimensionsKey
  parent: keyvault
  tags: tags
  properties: {
    value: embeddingModelDimensions
  }
}

resource apiKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  name: open_ai_openAISecretKey
  parent: keyvault
  tags: tags
  properties: {
    value: openAi.listKeys().key1
  }
}


output openAIServiceName string = openAi.name
output openAIServiceEndpoint string = openAi.properties.endpoint
output keySecretName string = apiKeySecret.name
output keySecretValue string = apiKeySecret.properties.secretUri
