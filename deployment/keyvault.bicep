param location string = resourceGroup().location
param tags object = {}

// Input parameters
param name string
param managedIdentityName string


// Get existing user managed identity resource
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing= {
  name: managedIdentityName
}


// Create keyvault resource
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: { family: 'A', name: 'standard' }
    enabledForTemplateDeployment: true
    enableRbacAuthorization: true
    enabledForDeployment: true
  }
}


// Assign permissions
param id_roles_arr array = ['b24988ac-6180-42a0-ab88-20f7382dd24c','00482a5a-887f-4fb3-b363-3b7fe8e74483'] // Contributor, KeyVault admin
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = [for id_role in id_roles_arr : {
  name: guid(resourceGroup().id, 'keyvault',id_role)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', id_role)
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
  }
]


// Output parameters
output AzureKeyVaultName string = keyVault.name
output AzureKeyVaultEndpoint string = keyVault.properties.vaultUri
