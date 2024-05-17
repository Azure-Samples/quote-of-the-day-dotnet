param SASkuName string
param location string
param name string
param SAKind string

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: name
  location: location
  kind: SAKind
  sku: {
    name: SASkuName
  }
}

output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
