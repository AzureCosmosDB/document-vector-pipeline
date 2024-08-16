var location = resourceGroup().location

// Input params
param funcAppStorageAccountName string
param funcAppStorageConnectionStringSecretName string
param funcAppStorageSkuName string
param appInsightsName string
param appServicePlanName string
param functionAppName string
param logAnalyticsName string
param managedIdentityName string
param keyVaultName string
param storageConnectionStringSecretName string
param tags object = {}


// Get existing managed identity resource
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing= {
  name: managedIdentityName
}

// Get existing keyvault resource
resource keyvault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: keyVaultName
}

// Create webapps storage account to hold webapps related resources
resource func_app_storage_account 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: funcAppStorageAccountName
  location: location
  sku: {
    name: funcAppStorageSkuName
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
  }
  resource blobService 'blobServices' = {
    name: 'default'
  }
}

// Save azure function storage account connection string to keyvault
var funcAppStorageConnectionStringValue = 'DefaultEndpointsProtocol=https;AccountName=${func_app_storage_account.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${func_app_storage_account.listKeys().keys[0].value}'
resource azureWebJobsStorageConnectionString 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  name: funcAppStorageConnectionStringSecretName
  parent: keyvault
  tags: tags
  properties: {
    value: funcAppStorageConnectionStringValue
  }
}

// Assign storage account contributor role to func_app_storage_account
param storage_account_id_roles array = ['ba92f5b4-2d11-453d-a403-e96b0029c9fe'] // Storage blob data contributor
resource roleAssignmentFuncStorageAccount 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = [for id_role in storage_account_id_roles : {
  name: guid(resourceGroup().id, '${func_app_storage_account.name}-webjobsrole', id_role)
  scope: func_app_storage_account
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', id_role)
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
  }
]

// Create a new Log Analytics workspace to back the Azure Application Insights instance
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: 1
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Application Insights instance
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    WorkspaceResourceId: logAnalytics.id
  }
}

// Web server farm
resource appservice_plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
  location: location
  kind: 'functionapp'
  sku: {
    name: 'Y1'
  }
  properties: {
  }
}

// Deploy the Azure Function app with application
resource funcApp 'Microsoft.Web/sites@2021-02-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    httpsOnly: true
    serverFarmId: appservice_plan.id
    keyVaultReferenceIdentity: managedIdentity.id
    enabled: true
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${funcAppStorageConnectionStringSecretName})'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          // TODO: Figure out why a keyvault reference isn't working here.
          // value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${funcAppStorageConnectionStringSecretName})'
          value: funcAppStorageConnectionStringValue
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet-isolated'
        }
        {
          name: 'netFrameworkVersion'
          value: 'v8.0'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'AzureBlobStorageAccConnectionString'
          value: '@Microsoft.KeyVault(VaultName=${keyVaultName};SecretName=${storageConnectionStringSecretName})'
        }
        {
          name: 'AzureKeyVaultEndpoint'
          value: keyvault.properties.vaultUri
        }
        {
          name: 'AzureManagedIdentityClientId'
          value: managedIdentity.properties.clientId
        }
      ]
    }
  }
}

// Assign storage account contributor role to azure function app
param id_roles_arr array = ['b24988ac-6180-42a0-ab88-20f7382dd24c','00482a5a-887f-4fb3-b363-3b7fe8e74483'] // Contributor, KeyVault admin
resource roleAssignmentFUnctionApp 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = [for id_role in id_roles_arr : {
  name: guid(resourceGroup().id, '${func_app_storage_account.name}-funcrole', id_role)
  scope: funcApp
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', id_role)
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
  }
]
