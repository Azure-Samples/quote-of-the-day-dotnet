metadata description = 'Configure online experimentation workspace'
targetScope = 'subscription'
param resourceId string
param resourceGroupname string
param principalId string
param principalType string

resource managedResourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' existing = {
  name:  resourceGroupname
}

var segments = split(resourceId, '/')
var resourceName = segments[length(segments) - 1]

resource workspace 'Microsoft.OnlineExperimentation/workspaces@2025-05-31-preview' existing = {
  name: resourceName
  scope: managedResourceGroup
}

module workspaceAccess './onlineExperimentation-access.bicep' = {
  name: 'online-experimentation-role-assignment'
  scope: managedResourceGroup
  params: {
    resourceName: resourceName
    principalId: principalId
    principalType: principalType
  }
}

output endpoint string = workspace.properties.endpoint

