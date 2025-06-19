
metadata description = 'Creates a Log Analytics Summary Rule.'
param logAnalyticsWorkspaceName string
param summaryRuleName string
param description string
param ruleType string = 'User'
param query string
param binSize int
param destinationTable string
param location string

resource workspaceName_summaryRule 'Microsoft.OperationalInsights/workspaces/summaryLogs@2023-01-01-preview' = {
  name: '${logAnalyticsWorkspaceName}/${summaryRuleName}'
  location: location
  properties: {
    ruleType: ruleType
    description: description
    ruleDefinition: {
      query: query
      binSize: binSize
      destinationTable: destinationTable
    }
  }
}

output id string = workspaceName_summaryRule.id
