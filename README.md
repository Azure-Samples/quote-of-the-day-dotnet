# Quote of the Day - ASP.NET Core

## Samples

- `QuoteOfTheDay`: the original web app using the Application Insights SDK.
- `QuoteOfTheDay-OpenTelemetry`: the same web app using OpenTelemetry telemetry and the Azure Monitor exporter. 

The Azure Developer CLI instructions below deploy the original sample by default. You can switch the same App Service to the OpenTelemetry sample without creating another set of Azure resources.

## Prerequisites

- Clone this repository.
- Install or update to Powershell 7 <https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7.4>
- Install or update Azure CLI <https://learn.microsoft.com/en-us/cli/azure/install-azure-cli>
- Install the .NET 8 SDK. Database setup installs `dotnet-ef` 8.0.8 if the tool is missing.
- Ensure you have the required permissions to deploy into the target Azure subscription. Either of the below sets of roles can be used:
  - Owner
  - Contributor & User Access Administrator
- In addition, the identity running `azd up` needs **App Configuration Data Owner** to create the `Greeting` feature flag. Assign this role manually as described below; Owner or Contributor alone does not grant this data-plane access.

## Use Azure Developer CLI

This application can be run using the [Azure Developer CLI](https://aka.ms/azd), or `azd`, with very few commands:

- Navigate to the root of the repository.
- Install [azd](https://aka.ms/azure-dev/install).
- Log in `azd` (if you haven't done it before) to your Azure account:

```sh
azd auth login
```

- Log in to the Azure CLI.
```sh
az login
```

- Initialize `azd` from the root of the repo.

```sh
azd init
```

- During init:
  - Enter an environment name for this deployment when prompted.
- Choose the sample to deploy using the instructions below. Skip this step to keep the original sample.

### Select the OpenTelemetry sample

Set the sample for the active `azd` environment:

```powershell
azd env set QUOTE_OF_THE_DAY_PROJECT QuoteOfTheDay-OpenTelemetry
```

In the root `azure.yaml`, change only the `project` value under `services.QuoteOfTheDay`:

```yaml
services:
    QuoteOfTheDay:
        project: QuoteOfTheDay-OpenTelemetry
        host: appservice
        language: dotnet
```

Keep the service key `QuoteOfTheDay` unchanged: it identifies the existing App Service. Keep the existing hooks as well. The project path selects what `azd` packages; `QUOTE_OF_THE_DAY_PROJECT` selects the database setup directory and the App Service startup DLL. Both values must match. The YAML path is shared by all environments in this checkout, so update it when switching environments with different samples.

The infrastructure reuses App Configuration (including the `Greeting` variant flag), Application Insights, Log Analytics, the App Service plan, and the App Service managed identity and reader permission. OpenTelemetry exports directly to the same Application Insights resource; no collector is required.

The prepackage hook applies the selected project's checked-in EF migrations to its local SQLite `app.db`, which is included in the published app. It does not generate new migrations or provision an Azure database.

To switch back to the original sample, set:

```powershell
azd env set QUOTE_OF_THE_DAY_PROJECT QuoteOfTheDay
```

Then restore `project: QuoteOfTheDay` in `azure.yaml` and run `azd up`.

### Provision and deploy

#### Manually grant App Configuration data access

The deployment template does not assign **App Configuration Data Owner** to the deploying identity. Before deployment, grant it using the Azure portal:

1. Open the target resource group, `rg-<environment-name>`, in the subscription selected for your `azd` environment. If it does not exist yet, create it with that exact name in your deployment region. If a previous `azd up` partially succeeded, use the resource group it already created.
2. Select **Access control (IAM)** > **Add** > **Add role assignment**.
3. Select **App Configuration Data Owner**, then **Next**.
4. For an interactive deployment, choose **User, group, or service principal**, select **Select members**, and select the account signed in through `azd auth login`. For automated deployments, select the service principal or managed identity actually running the deployment instead.
5. Select **Review + assign** to complete the assignment. You need permission to create role assignments, such as Owner or User Access Administrator at this scope; otherwise, ask an administrator to perform this step.
6. Allow up to 15 minutes for the assignment to propagate, then run `azd up` below. If an earlier deployment failed because this role was missing, rerun `azd up`; do not delete the existing resources.

The App Configuration store inherits this role assignment from the resource group. If the store already exists, you can instead perform these steps on the store's **Access control (IAM)** for narrower access; you do not need assignments at both scopes. Grant this role to the **deploying identity**, not the web app's managed identity, which retains its template-assigned **App Configuration Data Reader** role.

#### Run the deployment

- Create Azure resources and deploy the sample by running:

```sh
azd up
```

Use `azd up`, not just `azd deploy`, after switching samples so the infrastructure updates the startup command to `dotnet QuoteOfTheDay-OpenTelemetry.dll` or `dotnet QuoteOfTheDay.dll`. Switching replaces the app in the existing App Service; it does not run both samples side by side. An existing deployment may be briefly unavailable between the startup-command update and code deployment.

Each sample has its own local SQLite database. Switching samples does not migrate deployed accounts or data; back up any database you need to retain before redeploying.


### Deployment notes

- The operation takes a few minutes the first time it is ever run for an environment.
- At the end of the process, `azd` will display the `url` for the webapp. Follow that link to test the sample.
- You can run `azd up` after saving changes to the sample to re-deploy and update the sample.
- `azd down` is an easy way to delete the newly created resources.
- Report any problems by opening an issue in [this repo](https://github.com/Azure-Samples/quote-of-the-day-dotnet/issues).
- [FAQ and troubleshoot](https://learn.microsoft.com/azure/developer/azure-developer-cli/troubleshoot?tabs=Browser) for azd.


### Explore the app after deployment

After `azd up` succeeds, open the web app URL printed in its output. You can also find it in the Azure portal: open `rg-<environment-name>`, select the App Service, and select **Browse** on its Overview page.

1. **Browse the home page.** It displays a quote and a greeting controlled by the `Greeting` feature flag. The sample currently has one hard-coded quote, so refreshing does not change the quote.
2. **Register and log in.** Use the links at the top of the page and complete any account-confirmation step.
3. **Click the heart.** When logged in, this sends a `Like` telemetry event. When logged out, the heart changes visually but no `Like` event is recorded.
4. **Experiment with greetings.** In the Azure portal, open the App Configuration store in the same resource group, then select **Feature manager** > **Greeting**. Edit a variant's greeting or allocation and save. Allocate 100% to a variant with a greeting for a predictable result. Allow time for configuration refresh, then reload the app; additional requests may be needed to trigger and observe the refresh.

To see likes, open the associated **Application Insights** resource, select **Logs**, and run:

```kusto
customEvents
| where name == "Like"
| order by timestamp desc
| take 20
```

Telemetry can take a few minutes to appear. The original sample sends telemetry through the Application Insights SDK; the OpenTelemetry sample sends it through the Azure Monitor exporter to the same Application Insights resource.
