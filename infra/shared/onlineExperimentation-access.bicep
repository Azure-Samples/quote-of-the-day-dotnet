metadata description = 'Configure online experimentation workspace access'
param resourceName string
param principalId string
param principalType string

resource workspace 'Microsoft.OnlineExperimentation/workspaces@2025-05-31-preview' existing = {
  name: resourceName
}

resource onlineExperimentDataOwnerRole 'Microsoft.Authorization/roleAssignments@2022-04-01' existing = {
  name: '53747cdd-e97c-477a-948c-b587d0e514b2' // Online Experimentation Data Owner
}

resource dataOwnerUserRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, resourceGroup().id, principalId, onlineExperimentDataOwnerRole.id)
  scope: workspace
  properties: {
    principalId: principalId
    roleDefinitionId: onlineExperimentDataOwnerRole.id
    principalType: principalType
  }
}
