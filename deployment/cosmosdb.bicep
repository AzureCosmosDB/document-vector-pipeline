param location string = resourceGroup().location
param capabilities array = [
  { name: 'EnableServerless' }
  { name: 'EnableNoSQLVectorSearch' /*TODO: This doesn't seem to work on account creation.*/}
]

// Input parameters
param databaseName string
param name string
param tags object


// Create cosmosdb account
resource cosmosDB 'Microsoft.DocumentDB/databaseAccounts@2024-05-15' = {
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

// Assign user identity permissions to storage account
param managedIdentityName string
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' existing = {
  name: managedIdentityName
}

// Assign storage account contributor role to azure function app
param id_roles_arr array = ['b24988ac-6180-42a0-ab88-20f7382dd24c', '230815da-be43-4aae-9cb4-875f7bd000aa'] // Contributor (priviledged role), CosmosDB Operator, Data contributor
resource roleAssignmentFUnctionApp 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for id_role in id_roles_arr : {
    name: guid(resourceGroup().id, '${cosmosDB.name}-funcrole', id_role)
    scope: cosmosDB
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', id_role)
      principalId: managedIdentity.properties.principalId
    }
  }
]

// Create database
resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2024-05-15' = {
  parent: cosmosDB
  name: databaseName
  properties: {
    resource: {
      id: databaseName
    }
  }
  tags: tags
}

output CosmosDBAccountName string = cosmosDB.name
output CosmosDBEndpoint string = cosmosDB.properties.documentEndpoint
