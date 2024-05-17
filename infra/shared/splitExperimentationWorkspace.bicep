param name string
param location string
param logAnalyticsWorkspaceResourceId string
param storageAccountResourceId string
param SEWdataSourceEnabled bool
param SEWEntraApplicationId string
param SEWsku string
param storageBlobReaderRole string
param storageAccountName string

resource splitExperimentationWorkspaceResource 'SplitIO.Experimentation/experimentationWorkspaces@2024-03-01-preview' = {
  name: name
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: SEWsku
  }
  properties: {
    accessPolicy: {
      applicationId: SEWEntraApplicationId
    }
    dataSource: {
      logAnalytics: {
        resourceId: logAnalyticsWorkspaceResourceId
        storageAccountResourceId: storageAccountResourceId
        enabled: SEWdataSourceEnabled
      }
    }
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

resource splitWorkspaceResourceStorageBlobReaderRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(splitExperimentationWorkspaceResource.id, storageBlobReaderRole)
  properties: {
    roleDefinitionId: storageBlobReaderRole
    principalId: splitExperimentationWorkspaceResource.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output splitExperimentationWorkspaceResourceId string = splitExperimentationWorkspaceResource.id
output splitExperimentationWorkspaceName string = splitExperimentationWorkspaceResource.name
