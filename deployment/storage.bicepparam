using './storage.bicep'

param keyvaultName = 'docingkv'
param name = 'docingblobacc'
param storageConnectionStringSecretName = 'StorageAccConnectionStr'
param managedIdentityName = 'docinguseridentity'
param containers = [
  {
    name: 'documents'
  }
]

param tags = {}
