targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@secure()
param quoteOfTheDayDefinition object

param LAWname string
param location string
param LAWsku string
param AIname string
param AItype string
param AIrequestSource string
param AACname string
param AACsku string
param AACsoftDeleteRetentionInDays int
param AACenablePurgeProtection bool
param AACdisableLocalAuth bool

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

output APPCONFIG_ENDPOINT string = appConfiguration.outputs.appConfigurationEndpoint
output APPLICATIONINSIGHTS_CONNECTION_STRING string = monitoring.outputs.applicationInsightsConnectionString
