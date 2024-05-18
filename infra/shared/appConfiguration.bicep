param location string
param name string
param AACsku string
param AACsoftDeleteRetentionInDays int
param AACenablePurgeProtection bool
param AACdisableLocalAuth bool
param applicationInsightsName string
param splitExperimentationWorkspaceResourceId string
param dataplaneEndpoint string

resource appConfigurationStore 'Microsoft.AppConfiguration/configurationStores@2023-09-01-preview' = {
  name: name
  location: location
  sku: {
    name: AACsku
  }
  properties: {
    softDeleteRetentionInDays: AACsoftDeleteRetentionInDays
    enablePurgeProtection: AACenablePurgeProtection
    disableLocalAuth: AACdisableLocalAuth
    experimentation: {
      resourceId: splitExperimentationWorkspaceResourceId
      dataPlaneEndpoint: dataplaneEndpoint
    }
    telemetry: {
      resourceId: applicationInsightsName
    }
  }
}

resource variantFeatureFlagGreeting 'Microsoft.AppConfiguration/configurationStores/keyValues@2023-03-01' = {
  name: '.appconfig.featureflag~2FGreeting'
  parent: appConfigurationStore
  properties: {
    contentType: 'application/vnd.microsoft.appconfig.ff+json;charset=utf-8'
    value: '''
    {
      "id": "Greeting",
      "description": "",
      "enabled": true,
      "variants": [
        {
          "name": "On",
          "configuration_value": true
        },
        {
          "name": "Off",
          "configuration_value": false
        }
      ],
      "allocation": {
        "percentile": [
          {
            "variant": "On",
            "from": 0,
            "to": 50
          },
          {
            "variant": "Off",
            "from": 50,
            "to": 100
          }
        ],
        "default_when_enabled": "Off",
        "default_when_disabled": "Off"
      },
      "telemetry": {
        "enabled": true
      },
      "conditions": {
        "client_filters": [
          {
            "name": "AlwaysOn"
          }
        ]
      }
    }
    '''
  }
}

var readonlyKey = filter(appConfigurationStore.listKeys().value, k => k.name == 'Primary Read Only')[0]

output appConfigurationConnectionString string = readonlyKey.connectionString
output appConfigurationName string = appConfigurationStore.name
