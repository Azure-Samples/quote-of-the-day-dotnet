param(
    [Parameter(Mandatory=$True)]
    [string]
    $SubscriptionId,
    
    [Parameter(Mandatory=$True)]
    [string]
    $WorkspaceName,
    
    [Parameter(Mandatory=$True)]
    [string]
    $AppConfigurationName)

$FeatureName = "Greeting"

$MetricName = "Like"

function Setup-QuoteOfTheDayExperiment($subscriptionId, $workspaceName, $appConfigurationName)
{
    az account show >$null 2>$null

    if ($LASTEXITCODE -ne 0)
    {
        az login
    }
    
    az account set --subscription $SubscriptionId

    $workspace = Get-Workspace $subscriptionId $workspaceName

    $token = Get-SplitAccessToken $workspace

    ###########
    ## Experiment
    ###########

    Write-Host "Checking if experiment exists"

    $experiment = Get-Experiment $workspace $FeatureName $token

    if ($experiment -eq $null)
    {
        Write-Host "Creating experiment"

        Create-Experiment $workspace $FeatureName $token
    }

    ###########
    ## Experiment version
    ###########

    Write-Host "Checking if experiment version exists"

    $feature = Get-FeatureFlag $appConfigurationName $FeatureName

    if ($feature -eq $null)
    {
        throw "App Configuration feature flag not found. Experiment cannot be created."
    }

    $experimentVersion = Get-ExperimentVersion $workspace $FeatureName $feature.etag $token

    if ($experimentVersion -eq $null)
    {
        Write-Host "Creating experiment version"

        Create-ExperimentVersion $workspace $FeatureName $feature.etag $token
    }

    ###########
    ## Metric
    ###########

    Write-Host "Checking if metric exists"

    $metric = Get-Metric $workspace $MetricName $token

    if ($metric -eq $null)
    {
        Write-Host "Creating metric"

        Create-Metric $workspace $MetricName $token
    }
}

function Calculate-ExperimentId($key, $label)
{
    $hashInput = $null

    if ($label -eq $null)
    {
        $hashInput = "$key`n"
    }
    else
    {
        $hashInput = "$key`n$label"
    }

    $hashAlgorithm = [System.Security.Cryptography.HashAlgorithm]::Create('SHA256')
    
    $hash = $hashAlgorithm.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($hashInput))

    [System.Convert]::ToBase64String($hash).TrimEnd("=").Replace("+", "-").Replace("/", "_")
}

function Get-Workspaces($subscriptionId)
{
    $(az rest --method get --url  https://management.azure.com/subscriptions/$subscriptionId/providers/SplitIO.Experimentation/experimentationWorkspaces?api-version=2024-03-01-preview | convertfrom-json).value
}

function Get-Workspace($subscriptionId, $workspaceName)
{
    $workspaces = $(az rest --method get --url  https://management.azure.com/subscriptions/$subscriptionId/providers/SplitIO.Experimentation/experimentationWorkspaces?api-version=2024-03-01-preview | convertfrom-json).value

    $workspaces | Where { $_.name -eq $WorkspaceName }
}

function Get-SplitAccessToken($workspace)
{
    $(az account get-access-token --resource "api://$($workspace.properties.accessPolicy.applicationId)" | ConvertFrom-Json).accessToken
}

function Get-FeatureFlag($appConfigurationName, $featureName)
{
    $(az appconfig kv show --n $appConfigurationName --key ".appconfig.featureflag/$featureName" | ConvertFrom-Json)
}

function Get-Experiment($workspace, $featureName, $accessToken)
{
    $headers = @{
        Authorization = "Bearer $accessToken"
    }
    
    $experimentId = Calculate-ExperimentId ".appconfig.featureflag/$($featureName)"

    $(az rest `
        --method get `
        --url  "$($workspace.properties.accessPolicy.dataPlaneEndpoint)/v1/experimentation-workspaces/$($workspace.name)/experiments" `
        --skip-authorization-header `
        --headers $(ConvertTo-Json $headers).Replace("`r", "").Replace("`n", "").Replace("`"", "\`"") `
        | ConvertFrom-Json).experiments `
        | Where { $_.externalId -eq $experimentId }
}

function Create-Experiment($workspace, $featureName, $accessToken)
{
    $headers = @{
        Authorization = "Bearer $accessToken"
    }
    
    $experimentId = Calculate-ExperimentId ".appconfig.featureflag/$($featureName)"

    $body = @{
        name = $FeatureName
        description = $FeatureName
    }

    $experiment = az rest `
        --method put `
        --url  "$($workspace.properties.accessPolicy.dataPlaneEndpoint)/v1/experimentation-workspaces/$($workspace.name)/experiments/$experimentId" `
        --skip-authorization-header `
        --headers $(ConvertTo-Json $headers).Replace("`r", "").Replace("`n", "").Replace("`"", "\`"") `
        --body $(ConvertTo-Json $body).Replace("`r", "").Replace("`n", "").Replace("`"", "\`"")
}

function Get-ExperimentVersion($workspace, $featureName, $featureEtag, $accessToken)
{
    $headers = @{
        Authorization = "Bearer $accessToken"
    }
    
    $experimentId = Calculate-ExperimentId ".appconfig.featureflag/$($featureName)"
    
    $(az rest `
        --method get `
        --url  "$($workspace.properties.accessPolicy.dataPlaneEndpoint)/v1/experimentation-workspaces/$($workspace.name)/experiments/$experimentId/versions" `
        --skip-authorization-header `
        --headers $(ConvertTo-Json $headers).Replace("`r", "").Replace("`n", "").Replace("`"", "\`"") `
        | ConvertFrom-Json).versions `
        | Where { $_.experimentVersionId -eq $featureEtag }
}

function Create-ExperimentVersion($workspace, $featureName, $featureEtag, $accessToken)
{
    $headers = @{
        Authorization = "Bearer $accessToken"
    }
    
    $body = @{
        startTime = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    }

    $experimentId = Calculate-ExperimentId ".appconfig.featureflag/$($featureName)"

    $metric = az rest `
        --method put `
        --url  "$($workspace.properties.accessPolicy.dataPlaneEndpoint)/v1/experimentation-workspaces/$($workspace.name)/experiments/$experimentId/versions/$featureEtag" `
        --skip-authorization-header `
        --headers $(ConvertTo-Json $headers).Replace("`r", "").Replace("`n", "").Replace("`"", "\`"") `
        --body $(ConvertTo-Json $body).Replace("`r", "").Replace("`n", "").Replace("`"", "\`"")
}

function Get-Metric($workspace, $metricName, $accessToken)
{
    $headers = @{
        Authorization = "Bearer $accessToken"
    }
    
    $(az rest `
        --method get `
        --url  "$($workspace.properties.accessPolicy.dataPlaneEndpoint)/v1/experimentation-workspaces/$($workspace.name)/metrics" `
        --skip-authorization-header `
        --headers $(ConvertTo-Json $headers).Replace("`r", "").Replace("`n", "").Replace("`"", "\`"") `
        | ConvertFrom-Json).metrics `
        | Where { $_.name -eq $metricName }
}

function Create-Metric($workspace, $metricName, $accessToken)
{
    $headers = @{
        Authorization = "Bearer $accessToken"
    }
    
    $body = @{
        aggregation = "COUNT"
        direction = "INCREASE"
        eventType = $metricName
        name = $metricName
        description = ""
    }

    $metric = az rest `
        --method post `
        --url  "$($workspace.properties.accessPolicy.dataPlaneEndpoint)/v1/experimentation-workspaces/$($workspace.name)/metrics" `
        --skip-authorization-header `
        --headers $(ConvertTo-Json $headers).Replace("`r", "").Replace("`n", "").Replace("`"", "\`"") `
        --body $(ConvertTo-Json $body).Replace("`r", "").Replace("`n", "").Replace("`"", "\`"")
}

Setup-QuoteOfTheDayExperiment $SubscriptionId $WorkspaceName $AppConfigurationName
