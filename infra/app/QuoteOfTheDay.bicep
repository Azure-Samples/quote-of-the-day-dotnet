param name string
param location string = resourceGroup().location
param tags object = {}

param identityName string
param applicationInsightsName string
param exists bool
@secure()
param appDefinition object
param appConfigurationConnectionString string
param appServicePlanId string

// var appSettingsArray = filter(array(appDefinition.settings), i => i.name != '')
// var secrets = map(filter(appSettingsArray, i => i.?secret != null), i => {
//   name: i.name
//   value: i.value
//   secretRef: i.?secretRef ?? take(replace(replace(toLower(i.name), '_', '-'), '.', '-'), 32)
// })
// var env = map(filter(appSettingsArray, i => i.?secret == null), i => {
//   name: i.name
//   value: i.value
// })

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: applicationInsightsName
}

resource appService 'Microsoft.Web/sites@2023-01-01' = {
  name: name
  location: location
  tags: union(tags, {'azd-service-name':  'QuoteOfTheDay' })
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { '${identity.id}': {} }
  }
  properties: {
    serverFarmId: appServicePlanId
    siteConfig: {
      appSettings: [
        {
          name: 'ApplicationInsightsConnectionString'
          value: applicationInsights.properties.ConnectionString
        }
        {
          name: 'PORT'
          value: '80'
        }
        {
          name: 'AzureAppConfigurationConnectionString'
          value: appConfigurationConnectionString
        }
      ]
    }
  }
}

module configAppSettings '../shared/appservice-appsettings.bicep' = {
  name: '${name}-appSettings'
  params: {
    name: appService.name
  }
}

resource configLogs 'Microsoft.Web/sites/config@2023-01-01' = {
  name: 'logs'
  parent: appService
  properties: {
    applicationLogs: { fileSystem: { level: 'Verbose' } }
    detailedErrorMessages: { enabled: true }
    failedRequestsTracing: { enabled: true }
    httpLogs: { fileSystem: { enabled: true, retentionInDays: 1, retentionInMb: 35 } }
  }
  dependsOn: [configAppSettings]
}

output name string = appService.name
output uri string = 'https://${appService.properties.defaultHostName}'
