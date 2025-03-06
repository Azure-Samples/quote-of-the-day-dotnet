$databasePath = "./QuoteOfTheDay\*.db"
$databaseExists = Test-Path -Path $databasePath

if ($databaseExists) {
    Write-Host "The database file already exists."

    exit 0
}

Write-Host "Creating database file."

Set-Location -Path "./QuoteOfTheDay"

$dotnetSDK = dotnet --version
if ($dotnetSDK -eq $null) {
    winget install Microsoft.DotNet.SDK.8
} else {
    Write-Host "The .NET SDK is already installed."
}

# Set environment variable to indicate EF migrations are running from setup script
$env:RUNNING_EF_MIGRATIONS_SETUP = "true"

# Temporarily set Azure environment variables to null to prevent connection attempts
$env:APPCONFIG_ENDPOINT = $null
$env:APPLICATIONINSIGHTS_CONNECTION_STRING = $null

dotnet tool install --global dotnet-ef
dotnet ef migrations add InitialCreate
dotnet ef database update

# Clean up environment variable
$env:RUNNING_EF_MIGRATIONS_SETUP = $null

Write-Host "Created the database file."

Set-Location -Path ".."