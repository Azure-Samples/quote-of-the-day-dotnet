$hashAlgorithm = [System.Security.Cryptography.HashAlgorithm]::Create('SHA256')

$RawAppDisplayName = "$env:AZURE_SUBSCRIPTION_ID$AZURE_ENV_NAME$AZURE_LOCATION"

$HashedAppDisplayName = $hashAlgorithm.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($RawAppDisplayName))

$uniqueString = [System.Convert]::ToBase64String($HashedAppDisplayName).Substring(0, 13)

$AppDisplayName = "Split Experimentation - Quote of the Day - $uniqueString"

$SplitResourceProviderApplicationId = "d3e90440-4ec9-4e8b-878b-c89e889e9fbc"

$AzureCliApplicationId = "04b07795-8ddb-461a-bbee-02f9e1bf7b46"

function Setup-SplitExperimentationEntraApp
{
    ###########
    ## Context
    ###########

    az account show >$null 2>$null

    if ($LASTEXITCODE -ne 0)
    {
        az login
    }

    $userObjectId = $(az ad signed-in-user show | ConvertFrom-Json).id

    ###########
    ## Get or create app
    ###########

    Write-Host "Checking for existence of Entra ID app"

    $app = Get-SplitApp

    $folderPath = "./.azure/$env:AZURE_ENV_NAME"
    $envFile = Get-ChildItem -Path $folderPath -Filter "*.env" | Select-Object -First 1
    $envFilePath = $envFile.FullName
    $envVarName = "AZURE_SPLIT_ENTRA_APPLICATION_ID"
    $splitEntraAppId = $app.appId
    $envVarLine = "$envVarName=`"$splitEntraAppId`""

    # Only add the environment variable if it doesn't already exist with the correct value
    $entraAppIdEnvVarCorrectValue = Select-String -Path $envFilePath -Pattern $envVarLine -Quiet

    if (!$entraAppIdEnvVarCorrectValue) {
      $entraAppIdEnvVarExists = Select-String -Path $envFilePath -Pattern $envVarName -Quiet
      
      if ($entraAppIdEnvVarExists) {
        (Get-Content $envFilePath) | Where-Object { $_ -notmatch $envVarName } | Set-Content $envFilePath
      }

      Add-Content -Path $envFilePath -Value $envVarLine
    }

    if ($app -eq $null)
    {
        Write-Host "Creating Entra ID app"

        az ad app create --display-name "$AppDisplayName"

        $app = Get-SplitApp
    }

    ###########
    ## Create sp if non-existent
    ###########

    Write-Host "Checking for existence of Entra ID service principal"

    $sp = Get-SplitSp

    if ($sp -eq $null)
    {
        Write-Host "Creating service principal"

        Confirm-IsOwner $app.id $userObjectId

        az ad sp create --id $app.id
    }

    ###########
    ## App role
    ###########

    Write-Host "Checking for existence of app role"    

    $role = $app.appRoles | where { $_.value -eq "ExperimentationDataOwner" }

    if ($role -eq $null)
    {
        Write-Host "Creating app role"

        Confirm-IsOwner $app.id $userObjectId

        Add-AppRole $app.id
    }

    $app = Get-SplitApp

    ###########
    ## ID URIs
    ###########

    Write-Host "Checking for existence of ID URI"

    $idUriValue = "api://$($app.appId)"

    $idUri = $app.identifierUris | where { $_ -eq $idUriValue }

    if ($idUri -eq $null)
    {
        Write-Host "Creating ID URI"

        Confirm-IsOwner $app.id $userObjectId

        az ad app update --id $app.id --identifier-uris "api://$($app.appId)"
    }

    $app = Get-SplitApp

    ###########
    ## Scopes
    ###########

    Write-Host "Checking for API scopes"

    $perm = $app.api.oauth2PermissionScopes | where { $_.value -eq "user_impersonation" }

    if ($perm -eq $null)
    {
        Write-Host "Creating API scope"

        Confirm-IsOwner $app.id $userObjectId

        Add-ApiScope $app.id
    }

    $app = Get-SplitApp

    ###########
    ## Preauthorize Split resource provider
    ###########

    Write-Host "Checking for Split RP preauthorization"

    $authorization = $app.api.preAuthorizedApplications | where { $_.appId -eq $SplitResourceProviderApplicationId }

    if ($authorization -eq $null)
    {
        Write-Host "Setting up Split RP preauthorization for Entra ID token acquisition"

        Confirm-IsOwner $app.id $userObjectId

        $perm = $app.api.oauth2PermissionScopes | where { $_.value -eq "user_impersonation" }

        Preauthorize-SplitResourceProvider $app.id $perm.id
    }

    $app = Get-SplitApp

    ###########
    ## Preauthorize Azure CLI
    ###########

    Write-Host "Checking for Azure CLI preauthorization"

    $authorization = $app.api.preAuthorizedApplications | where { $_.appId -eq $AzureCliApplicationId }

    if ($authorization -eq $null)
    {
        Write-Host "Setting up Azure CLI preauthorization for Entra ID token acquisition"

        Confirm-IsOwner $app.id $userObjectId

        $perm = $app.api.oauth2PermissionScopes | where { $_.value -eq "user_impersonation" }

        Preauthorize-AzureCli $app.id $perm.id
    }

    $app = Get-SplitApp

    ###########
    ## Required resource access
    ###########

    Write-Host "Checking for required resource access configuration"

    if ($app.requiredResourceAccess.Length -eq 0)
    {
        Write-Host "Establishing required resource access"

        Confirm-IsOwner $app.id $userObjectId

        Add-RequiredResourceAccess $app.id
    }

    $app = Get-SplitApp

    ###########
    ## Role assignment
    ###########
    
    Write-Host "Checking role assignment for experimentation data owner"

    $sp = Get-SplitSp

    $tenantId = $(az account show | ConvertFrom-Json).tenantId

    $appRoleId = $($app.appRoles | where { $_.Value -eq "ExperimentationDataOwner" }).id

    $roleAssignments = Get-AppRoleAssignments $tenantId $sp.id

    $roleAssignment = $roleAssignments.Value | where { $_.id -eq $appRoleId }

    if ($roleAssignment -eq $null)
    {
        Write-Host "Creating role assignment for experimentation data owner"

        Confirm-IsOwner $app.id $userObjectId

        Add-AppRoleAssignment $tenantId $sp.id $appRoleId $userObjectId
    }
}

function Add-AppRole($objectId)
{
    $app = Get-SplitApp

    $appRole = @{
        allowedMemberTypes = @(
            "User",
            "Application"
        )
        description = "data owner"
        displayName = "ExperimentationDataOwner"
        isEnabled = $true
        value = "ExperimentationDataOwner"
    }

    $appRoles = @()

    $app.appRoles | %{ $appRoles += $_ }

    $appRoles += $appRole

    $app.appRoles = $appRoles

  az ad app update --id $objectId --app-roles $(ConvertTo-Json $app.appRoles).Replace("`r", "").Replace("`n", "").Replace("`"", "\`"")
}

function Add-ApiScope($objectId)
{
    $app = Get-SplitApp

    $permissionId = [guid]::NewGuid().ToString()

    $permission = @{
        adminConsentDescription = "Allows access to the split experimentation workspace"
        adminConsentDisplayName = "Split Experimentation Access"
        isEnabled = $true
        id = $permissionId
        type = "Admin"
        userConsentDescription = "Allows access to the split experimentation workspace"
        userConsentDisplayName = "Split Experimentation Access"
        value = "user_impersonation"
    }
    
    $permissions = @()

    $app.api.oauth2PermissionScopes | %{ $permissions += $_ }

    $permissions += $permission

    $app.api.oauth2PermissionScopes = $permissions

    $str = $(ConvertTo-Json $app.api).Replace("`r", "").Replace("`n", "").Replace("`"", "\`"")

    az ad app update --id $objectId --set api=$str
}

function Preauthorize-SplitResourceProvider($objectId, $permissionId)
{
    $app = Get-SplitApp

    $rpPreauthorization = @{
        appId = $SplitResourceProviderApplicationId
        delegatedPermissionIds = @(
            $permissionId
        )
    }

    $preauthorizations = @()

    $app.api.preAuthorizedApplications | %{ $preauthorizations += $_ }

    $preauthorizations += $rpPreauthorization

    $app.api.preAuthorizedApplications = $preauthorizations

    $str = $(ConvertTo-Json $app.api -Depth 10).Replace("`r", "").Replace("`n", "").Replace("`"", "\`"")

    az ad app update --id $objectId --set "api=$str"
}

function Preauthorize-AzureCli($objectId, $permissionId)
{
    $app = Get-SplitApp

    $cliPreauthorization = @{
        appId = $AzureCliApplicationId
        delegatedPermissionIds = @(
            $permissionId
        )
    }

    $preauthorizations = @()

    $app.api.preAuthorizedApplications | %{ $preauthorizations += $_ }

    $preauthorizations += $cliPreauthorization

    $app.api.preAuthorizedApplications = $preauthorizations

    $str = $(ConvertTo-Json $app.api -Depth 10).Replace("`r", "").Replace("`n", "").Replace("`"", "\`"")

    az ad app update --id $objectId --set "api=$str"
}

function Add-RequiredResourceAccess($objectId)
{
    $app = Get-SplitApp

    $rra = @{
        resourceAppId = "00000003-0000-0000-c000-000000000000"
        resourceAccess = @(
            @{
              id = "e1fe6dd8-ba31-4d61-89e7-88639da4683d"
              type = "Scope"
            }
        )
    }

    $rras = @()

    $app.requiredResourceAccess | %{ $rras += $_ }

    $rras += $rra

    $app.requiredResourceAccess = $rras

    $str = $(ConvertTo-Json $app.requiredResourceAccess -Depth 10).Replace("`r", "").Replace("`n", "").Replace("`"", "\`"")

    az ad app update --id $objectId --set "requiredResourceAccess=$str"
}

function Get-SplitApp()
{
    $apps = az ad app list --display-name $AppDisplayName | ConvertFrom-Json

    if ($apps.Length -eq 0)
    {
      return
    }

    $apps[0]
}

function Get-SplitSp()
{
    $sps = az ad sp list --display-name $AppDisplayName | ConvertFrom-Json

    if ($sps.Length -eq 0)
    {
      return
    }

    $sps[0]
}

function Get-AppRoleAssignments($tenantId, $appObjectId)
{
    az rest --method GET --uri "https://graph.windows.net/$tenantId/servicePrincipals/$appObjectId/appRoleAssignments?api-version=1.6" | ConvertFrom-Json
}

function Add-AppRoleAssignment($tenantId, $appObjectId, $appRoleId, $userObjectId)
{
    $BODY="{\`"id\`":\`"$appRoleId\`",\`"principalId\`":\`"$userObjectId\`",\`"resourceId\`":\`"$appObjectId\`"}"

    az rest --method post --uri "https://graph.windows.net/$tenantId/servicePrincipals/$appObjectId/appRoleAssignments?api-version=1.6" --body "$BODY" --headers "Content-type=application/json"
}

function Confirm-IsOwner($appObjectId, $userObjectId)
{
    $owners = az ad app owner list --id $appObjectId | ConvertFrom-Json

    $owner = $owners | where { $_.id -eq $userObjectId }

    if ($owner -eq $null)
    {
      $u = az ad signed-in-user show | ConvertFrom-Json

      throw "The caller $($u.userPrincipalName) is not listed as an owner of the application $($appObjectId). Ownership is required to perform setup."
    }
}

Setup-SplitExperimentationEntraApp
