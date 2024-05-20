targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

param quoteOfTheDayExists bool
@secure()
param quoteOfTheDayDefinition object

param LAWname string
param location string
param LAWsku string
param SAName string
param SAKind string
param SASkuName string
param storageAccountRuleName string = 'storage-account-rule-name'
param AIname string
param AItype string
param AIrequestSource string
param SEWname string
param SEWsku string
param SEWdataSourceEnabled bool
param SEWEntraApplicationId string
param AACname string
param AACsku string
param AACsoftDeleteRetentionInDays int
param AACenablePurgeProtection bool
param AACdisableLocalAuth bool
param DPendpoint string = 'https://asi.us.az.split.io/v1/experimentation-workspaces/'

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

var storageBlobReaderRole = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
var dataplaneEndpoint = '${DPendpoint}${SEWname}${resourceToken}'

resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

module storageAccount './shared/storageaccount.bicep' = {
  name: 'storageAccount'
  params: {
    location: location
    SAKind: SAKind
    name: substring('${SAName}${resourceToken}', 0, 20)
    SASkuName: SASkuName
  }
  scope: rg
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
    storageAccountResourceId: storageAccount.outputs.storageAccountId
    storageAccountRuleName: storageAccountRuleName
  }
  scope: rg
}

module registry './shared/registry.bicep' = {
  name: 'registry'
  params: {
    location: location
    tags: tags
    name: '${abbrs.containerRegistryRegistries}${resourceToken}'
  }
  scope: rg
}

module splitExperimentationWorkspace './shared/splitExperimentationWorkspace.bicep' = {
  name: 'splitExperimentationWorkspace'
  params: {
    location: location
    name: '${SEWname}${resourceToken}'
    SEWsku: SEWsku
    SEWdataSourceEnabled: SEWdataSourceEnabled
    SEWEntraApplicationId: SEWEntraApplicationId
    logAnalyticsWorkspaceResourceId: monitoring.outputs.logAnalyticsWorkspaceId
    storageAccountResourceId: storageAccount.outputs.storageAccountId
    storageBlobReaderRole: storageBlobReaderRole
    storageAccountName: storageAccount.outputs.storageAccountName
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
    dataplaneEndpoint: dataplaneEndpoint
    splitExperimentationWorkspaceResourceId: splitExperimentationWorkspace.outputs.splitExperimentationWorkspaceResourceId
  }
  scope: rg
}

module appsEnv './shared/apps-env.bicep' = {
  name: 'apps-env'
  params: {
    name: '${abbrs.appManagedEnvironments}${resourceToken}'
    location: location
    tags: tags
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    logAnalyticsWorkspaceName: monitoring.outputs.logAnalyticsWorkspaceName
  }
  scope: rg
}

module quoteOfTheDay './app/QuoteOfTheDay.bicep' = {
  name: 'QuoteOfTheDay'
  params: {
    name: '${abbrs.appContainerApps}quoteoftheda-${resourceToken}'
    location: location
    tags: tags
    identityName: '${abbrs.managedIdentityUserAssignedIdentities}quoteoftheda-${resourceToken}'
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    containerAppsEnvironmentName: appsEnv.outputs.name
    containerRegistryName: registry.outputs.name
    exists: quoteOfTheDayExists
    appDefinition: quoteOfTheDayDefinition
    appConfigurationConnectionString: appConfiguration.outputs.appConfigurationConnectionString
  }
  scope: rg
}

output AZURE_CONTAINER_REGISTRY_ENDPOINT string = registry.outputs.loginServer
output AZURE_SPLIT_WORKSPACE_NAME string = splitExperimentationWorkspace.outputs.splitExperimentationWorkspaceName
output AZURE_APPCONFIGURATION_NAME string = appConfiguration.outputs.appConfigurationName
