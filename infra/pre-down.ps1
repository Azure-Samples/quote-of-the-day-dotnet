# Get the directory of the current script
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Load environment variables from azd env
$subscriptionId = azd env get-value AZURE_SUBSCRIPTION_ID
$resourceName = azd env get-value APPCONFIG_RESOURCE_NAME
$resourceGroup = azd env get-value AZURE_RESOURCE_GROUP
$experimentationResourceId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.AppConfiguration/configurationStores/$resourceName/experimentation/default"

# Check resource existence by examining the exit code
az resource show --ids $experimentationResourceId --api-version 2025-02-01-preview --output none 2>$null
$resourceExists = $?

if ($resourceExists) {
    Write-Host "Disabling online experimentation for App Configuration resource: $experimentationResourceId"
    az resource delete --ids $experimentationResourceId --api-version 2025-02-01-preview
} else {
    Write-Host "Online experimentation not enabled, skipping online experimentation disable step"
}