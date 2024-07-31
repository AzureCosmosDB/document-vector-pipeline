param location string = resourceGroup().location
param capabilities array = [
  { name: 'EnableServerless' }
  { name: 'EnableNoSQLVectorSearch' /*TODO: This doesn't seem to work on account creation.*/}
]

// Input parameters
param containers array
param databaseName string
param keyvaultName string
param secretName string
param name string
param tags object


// Create cosmosdb account
resource cosmosDB 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: name
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    databaseAccountOfferType: 'Standard'
    locations: [
      {
        failoverPriority: 0
        isZoneRedundant: false
        locationName: location
      }
    ]
    capabilities: capabilities
  }
  tags: tags
}


// Create database
resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2023-04-15' = {
  parent: cosmosDB
  name: databaseName
  properties: {
    resource: {
      id: databaseName
    }
  }
  tags: tags
}


// Create cosmosdb container
// Disabled for now, because we can't create containers with a vector embedding policy right after
// creating the account yet, as the capability takes some time to propagage. Instead, we'll rely on the
// CreateContainerIfNotExists call in the application code.
// resource cosmosContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2024-05-15' = [
//   for container in containers: {
//     parent: database
//     name: container.name
//     properties: {
//       resource: {
//         id: container.name
//         partitionKey: {
//           paths: [
//             container.partitionKeyPath
//           ]
//           kind: 'Hash'
//           version: 2
//         }
//         indexingPolicy: container.indexingPolicy
//         vectorEmbeddingPolicy: container.vectorEmbeddingPolicy
//       }
//     }
//     tags: tags
//   }
// ]


// Persist secrets to keyvault
resource keyvault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  name: keyvaultName
}

resource cosmosKey 'Microsoft.KeyVault/vaults/secrets@2023-02-01' = {
  name: secretName
  parent: keyvault
  tags: tags
  properties: {
    value: cosmosDB.listConnectionStrings().connectionStrings[0].connectionString
  }
}

output CosmosDBAccountName string = cosmosDB.name
output CosmosDBEndpoint string = cosmosDB.properties.documentEndpoint
output CosmosDBKeySecretName string = cosmosKey.name
output CosmosDBKeyVaultReference string = cosmosKey.properties.secretUri
