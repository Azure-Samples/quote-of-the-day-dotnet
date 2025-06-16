# Get the directory of the current script
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Check if user is logged in to Azure CLI
az account show --output none 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Not logged in to Azure CLI. Please run 'az login' first."
    exit 1
}

# Load environment variables from azd env
$subscriptionId = azd env get-value AZURE_SUBSCRIPTION_ID
$resourceName = azd env get-value APPCONFIG_RESOURCE_NAME
$resourceGroup = azd env get-value AZURE_RESOURCE_GROUP
$experimentationResourceId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.AppConfiguration/configurationStores/$resourceName/experimentation/default"

# Check experimentation resource existence
az resource show --ids $experimentationResourceId --api-version 2025-02-01-preview --output none 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Disabling online experimentation for App Configuration resource: $experimentationResourceId"
    az resource delete --ids $experimentationResourceId --api-version 2025-02-01-preview
} else {
    Write-Host "Online experimentation not enabled, skipping online experimentation disable step"
    exit 0
}