targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@secure()
param quoteOfTheDayDefinition object
param location string

param LAWname string
param LAWsku string
param AIname string
param AItype string
param AIrequestSource string

param AACname string
param AACsku string
param AACsoftDeleteRetentionInDays int
param AACenablePurgeProtection bool
param AACdisableLocalAuth bool

param principalId string
param principalType string = 'User'

@description('Enable online experimentation (preview), currently only available in the East US 2 and Sweden Central regions.')
param enableOnlineExperimentation bool

// Tags that should be applied to all resources.
// 
// Note that 'azd-service-name' tags should be applied separately to service host resources.
// Example usage:
//   tags: union(tags, { 'azd-service-name': <service name in azure.yaml> })
var tags = {
  'azd-env-name': environmentName
}

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))

resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

module monitoring './shared/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    location: location
    logAnalyticsName: '${LAWname}${resourceToken}'
    applicationInsightsName: '${AIname}${resourceToken}'
    AIrequestSource: AIrequestSource
    AItype: AItype    
    LAWsku: LAWsku
    tags: tags
    principalId: principalId
    principalType: principalType
  }
  scope: rg
}

module appConfiguration './shared/appConfiguration.bicep' = {
  name: 'appConfiguration'
  params: {
    AACdisableLocalAuth: AACdisableLocalAuth
    AACenablePurgeProtection: AACenablePurgeProtection
    AACsoftDeleteRetentionInDays: AACsoftDeleteRetentionInDays
    AACsku: AACsku
    location: location
    name: '${AACname}${resourceToken}'
    applicationInsightsId: monitoring.outputs.applicationInsightsId
    enableOnlineExperimentation: enableOnlineExperimentation
  }
  scope: rg
}

module appServicePlan './shared/appserviceplan.bicep' = {
  name: 'apps-env'
  params: {
    name: '${abbrs.appManagedEnvironments}${resourceToken}'
    location: location
    tags: tags
  }
  scope: rg
}

module quoteOfTheDay './app/QuoteOfTheDay.bicep' = {
  name: 'QuoteOfTheDay'
  params: {
    name: '${abbrs.appContainerApps}quoteoftheda-${resourceToken}'
    location: location
    tags: tags
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    appDefinition: quoteOfTheDayDefinition
    appServicePlanId: appServicePlan.outputs.id
    appConfigurationName: appConfiguration.outputs.appConfigurationName
  }
  scope: rg
}

// Setup for online experimentation if enabled
// Including adding summary rules and data export rule to Log Analytics
module onlineExperimentationWorkspace 'shared/onlineExperimentation.bicep' = if (enableOnlineExperimentation) {
  name: 'online-experimentation-${resourceToken}'
  scope: subscription()
  params: {
    resourceId: appConfiguration.outputs.onlineExperimentationResourceId
    resourceGroupname: appConfiguration.outputs.managedResourceGroupName
    principalId: principalId
    principalType: principalType
  }
}


var ruleDefinitions = loadYamlContent('shared/la-summary-rules.yaml')
module summaryRules 'shared/summaryRule.bicep' = [for (rule, i) in ruleDefinitions.summaryRules: if (enableOnlineExperimentation) {
  name: 'loganalytics-summaryrule-${i}'
  scope: rg
  params: {
    location: location
    logAnalyticsWorkspaceName: monitoring.outputs.logAnalyticsWorkspaceName
    summaryRuleName: rule.name
    description: rule.description
    query: rule.query
    binSize: rule.binSize
    destinationTable: rule.destinationTable
  }
}]

module dataExportRule 'shared/dataExport.bicep' = if (enableOnlineExperimentation) {
  name: 'loganalytics-dataexportrule'
  scope: rg
  params: {
    name: 'OEW-${resourceToken}-DataExportRule'
    logAnalyticsWorkspaceName: monitoring.outputs.logAnalyticsWorkspaceName
    storageAccountResourceId: appConfiguration.outputs.storageAccountResourceId
    tables: [
      'AppEvents'
    ]
  }
}

output AZURE_RESOURCE_GROUP string = rg.name
output APPCONFIG_RESOURCE_NAME string = appConfiguration.outputs.appConfigurationName
output APPCONFIG_ENDPOINT string = appConfiguration.outputs.appConfigurationEndpoint
output APPLICATIONINSIGHTS_CONNECTION_STRING string = monitoring.outputs.applicationInsightsConnectionString
