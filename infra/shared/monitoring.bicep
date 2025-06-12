param logAnalyticsName string
param applicationInsightsName string
param location string = resourceGroup().location
param AItype string
param AIrequestSource string
param LAWsku string
param tags object = {}
param principalId string
param principalType string

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: logAnalyticsName
  location: location
  tags: tags
  properties: {
    sku: {
      name: LAWsku
    }
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  tags: tags
  kind: 'other'
  properties: {
    Application_Type: AItype
    Flow_Type: 'Bluefield'
    Request_Source: AIrequestSource
    WorkspaceResourceId: logAnalytics.id
  }
}

// Assign the Log Analytics Contributor role to the specified principal
var logAnalyticsContributorRoleId = '92aaf0da-9dab-42b6-94a3-d43ce8d16293'
resource role 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, resourceGroup().id, principalId, logAnalyticsContributorRoleId)
  properties: {
    principalId: principalId
    principalType: principalType
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', logAnalyticsContributorRoleId)
  }
}

output applicationInsightsName string = applicationInsights.name
output applicationInsightsId string = applicationInsights.id
output logAnalyticsWorkspaceId string = logAnalytics.id
output logAnalyticsWorkspaceName string = logAnalytics.name
output applicationInsightsConnectionString string = applicationInsights.properties.ConnectionString
