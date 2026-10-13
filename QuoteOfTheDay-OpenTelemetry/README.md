# Quote of the Day - OpenTelemetry

This .NET 8 Razor Pages sample preserves the quote, greeting variants, Identity sign-in, and Like button from `QuoteOfTheDay`. It uses `Microsoft.FeatureManagement.Telemetry.OpenTelemetry` instead of the Application Insights SDK integration. Azure Monitor remains the telemetry destination, using `Azure.Monitor.OpenTelemetry.AspNetCore`.

**Trying this app for the first time?** Start with the [root README](../README.md) for prerequisites, Azure resource setup, and deployment instructions, including how to select the OpenTelemetry sample.

If you already have an Azure App Configuration store with the `Greeting` variant feature flag [configured](https://learn.microsoft.com/en-us/azure/azure-app-configuration/howto-variant-feature-flags), continue with the step-by-step local setup instructions below to use your existing resources.

## Run locally

Follow these steps to build and run locally using an existing Azure App Configuration store and `Greeting` feature flag. No `azd provision` or `azd up` is needed, and these steps do not create Azure resources.

### 1. Open PowerShell in the repository

Install the .NET 8 SDK, PowerShell 7, and Azure CLI. Navigate to your repository root (the directory containing `azure.yaml` and `infra`), replacing the example path with your checkout location:

```powershell
Set-Location "C:\path\to\quote-of-the-day-dotnet"
```

### 2. Initialize the local database

```powershell
.\infra\Setup-CreateDatabase.ps1 -ProjectName QuoteOfTheDay-OpenTelemetry
```

The script installs `dotnet-ef` 8.0.8 if the tool is missing and applies the checked-in migrations to this project's SQLite `app.db`. It manages `RUNNING_EF_MIGRATIONS_SETUP` automatically and restores the previous environment afterward. Do not generate new migrations for initial setup.

### 3. Enter the app directory and sign in

```powershell
Set-Location .\QuoteOfTheDay-OpenTelemetry
az login
```

Your signed-in identity needs the **App Configuration Data Reader** role on the existing store. An authorized administrator can assign this through the store's **Access control (IAM)** page in the Azure portal. The App Service managed identity's permissions do not grant access to your local identity.

### 4. Configure the existing App Configuration store

Replace the placeholder with the endpoint from your store's **Overview** page:

```powershell
dotnet user-secrets set "APPCONFIG_ENDPOINT" "https://<your-store>.azconfig.io"
```

In the store's Feature manager, ensure `Greeting` is enabled, has **no label**, and is a variant feature flag with string-valued variants. The app's default feature-flag selection uses the null (no-label) label. The repository's sample flag allocates 50% to `Default`, 25% to `Simple` (`Hello!`), and 25% to `Long` (`I hope this makes your day!`); you can use your existing string-valued variants instead. You can find the feature flag setup steps [here](https://learn.microsoft.com/en-us/azure/azure-app-configuration/howto-variant-feature-flags). Or use our `infra/` for deployment. 

### 5. Configure telemetry (optional)

To export telemetry, copy the connection string from an existing Application Insights resource's **Overview** page and set:

```powershell
dotnet user-secrets set "APPLICATIONINSIGHTS_CONNECTION_STRING" "<your-connection-string>"
```

Enable telemetry on the `Greeting` flag (`"telemetry": { "enabled": true }`) to receive feature-evaluation events. Skip this step if you do not need telemetry export.

### 6. Build and run

Run these commands from the `QuoteOfTheDay-OpenTelemetry` directory:

```powershell
$env:ASPNETCORE_ENVIRONMENT = "Development"

dotnet build
dotnet run --no-build --urls "http://localhost:5000"
```

### 7. Open the app

Open `http://localhost:5000`, register an account, and use the development-only confirmation link on the registration confirmation page before signing in. Load the home page to evaluate `Greeting`, then click the heart to emit a `Like` event. Anonymous Like requests are rejected, as in the original sample.

Press **Ctrl+C** in PowerShell to stop the app.

For a basic local run without Azure, skip the Azure sign-in and configuration steps and leave the Azure settings unset. Without an App Configuration endpoint, the app uses local configuration; without a `Greeting` flag, it displays the quote without a greeting and logs a warning. Without an Application Insights connection string, the app still runs but does not export telemetry.

## Telemetry

- `AddFeatureManagementProcessors()` publishes `FeatureEvaluation` custom events and registers targeting enrichment for logs and traces. It is called **before** `UseAzureMonitor()`.
- `UseAzureMonitor()` configures OpenTelemetry logs, traces, metrics, and Azure Monitor export. Rate-limited sampling is disabled and trace sampling is set to 100%, preserving the original sample's disabled adaptive sampling. Trace-based log sampling is also disabled so experiment events are retained even under an unsampled parent trace.
- Authentication runs before `TargetingHttpContextMiddleware`, so the signed-in user's targeting ID is available for evaluation and Like events.
- `Like` is an `ILogger` event with the `microsoft.custom_event.name` attribute, not a `TelemetryClient.TrackEvent` call. Azure Monitor maps it to `customEvents`.

In your Application Insights resource, query:

```kusto
customEvents
| where name in ("FeatureEvaluation", "Like")
| extend TargetingId = tostring(customDimensions.TargetingId),
         Variant = tostring(customDimensions.Variant)
| project timestamp, name, TargetingId, Variant, customDimensions
| order by timestamp desc
```

Evaluation events require telemetry to be enabled on the flag. Keep Information-level logging enabled for feature management and `QuoteOfTheDay.Pages.IndexModel` so evaluation and Like events are not filtered out.