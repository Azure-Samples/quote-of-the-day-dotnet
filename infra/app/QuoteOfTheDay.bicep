param name string
param location string = resourceGroup().location
param tags object = {}

param identityName string
param applicationInsightsName string
param appConfigurationConnectionString string
param appServicePlanId string

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
      appCommandLine: 'dotnet QuoteOfTheDay.dll'
      linuxFxVersion: 'DOTNETCORE|8.0'
      alwaysOn: true
      // appSettings: [
      //   {
      //     name: 'ApplicationInsightsConnectionString'
      //     value: applicationInsights.properties.ConnectionString
      //   }
      //   {
      //     name: 'AzureAppConfigurationConnectionString'
      //     value: appConfigurationConnectionString
      //   }
      // ]
    }
  }
}

module configAppSettings '../shared/appservice-appsettings.bicep' = {
  name: '${name}-appSettings'
  params: {
    name: appService.name
    appSettings: union(
      {
        ApplicationInsightsConnectionString: applicationInsights.properties.ConnectionString
      },
      {
        ENABLE_ORYX_BUILD: true
      },
      {
        SCM_DO_BUILD_DURING_DEPLOYMENT: false
      },
      {
        AzureAppConfigurationConnectionString: appConfigurationConnectionString
      })
  }
}

output name string = appService.name
output uri string = 'https://${appService.properties.defaultHostName}'
