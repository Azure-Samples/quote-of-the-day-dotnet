param(
    [ValidateSet("QuoteOfTheDay", "QuoteOfTheDay-OpenTelemetry")]
    [string]$ProjectName = $(if ([string]::IsNullOrEmpty($env:QUOTE_OF_THE_DAY_PROJECT)) {
        "QuoteOfTheDay"
    } else {
        $env:QUOTE_OF_THE_DAY_PROJECT
    })
)

$ErrorActionPreference = "Stop"
$projectPath = Join-Path (Split-Path $PSScriptRoot -Parent) $ProjectName
$previousMigrationSetup = $env:RUNNING_EF_MIGRATIONS_SETUP
$previousAppConfigEndpoint = $env:APPCONFIG_ENDPOINT
$previousInsightsConnectionString = $env:APPLICATIONINSIGHTS_CONNECTION_STRING

Push-Location $projectPath
try {
    dotnet --version
    if ($LASTEXITCODE -ne 0) {
        throw "The .NET 8 SDK is required to initialize the database."
    }

    dotnet ef --version
    if ($LASTEXITCODE -ne 0) {
        dotnet tool install --global dotnet-ef --version 8.0.8
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to install dotnet-ef."
        }
    }

    $env:RUNNING_EF_MIGRATIONS_SETUP = "true"
    $env:APPCONFIG_ENDPOINT = $null
    $env:APPLICATIONINSIGHTS_CONNECTION_STRING = $null

    # Apply checked-in migrations, including pending ones on an existing database.
    dotnet ef database update
    if ($LASTEXITCODE -ne 0) {
        throw "Database setup failed for $ProjectName."
    }

    Write-Host "Database is ready for $ProjectName."
} finally {
    $env:RUNNING_EF_MIGRATIONS_SETUP = $previousMigrationSetup
    $env:APPCONFIG_ENDPOINT = $previousAppConfigEndpoint
    $env:APPLICATIONINSIGHTS_CONNECTION_STRING = $previousInsightsConnectionString
    Pop-Location
}