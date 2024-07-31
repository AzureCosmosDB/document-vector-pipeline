using './functionapp.bicep'

param managedIdentityName = 'docinguseridentity'
param keyVaultName = 'docingkv'
param functionAppName = 'docingfunc'

param funcAppStorageSkuName = 'Standard_LRS'
param funcAppStorageAccountName = '${functionAppName}store'
param appInsightsName = '${functionAppName}insight'
param appServicePlanName = '${functionAppName}service'
param logAnalyticsName = '${functionAppName}log'
param funcAppStorageConnectionStringSecretName = 'AzureWebJobsStorageConnectionString'
param storageConnectionStringSecretName = 'AzureBlobStorageAccConnectionString'
