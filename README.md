# QuoteOfTheDayAZD

## Prerequisites

- Clone this repository.
- Install or update to Powershell 7 <https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7.4>
- Install or update Azure CLI <https://learn.microsoft.com/en-us/cli/azure/install-azure-cli>
- Ensure you have the required permissions to deploy into the target Azure subscription. Either of the below sets of roles can be used:
  - Owner
  - Contributor & User Access Administrator

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
- Create Azure resources and deploy the sample by running:

```sh
azd up
```

Notes:

- The operation takes a few minutes the first time it is ever run for an environment.
- At the end of the process, `azd` will display the `url` for the webapp. Follow that link to test the sample.
- You can run `azd up` after saving changes to the sample to re-deploy and update the sample.
- `azd down` is an easy way to delete the newly created resources. The Entra App Registration will not be removed and must be removed separately.
- Report any problems by opening an issue in [this repo](https://github.com/Azure-Samples/quote-of-the-day-dotnet/issues).
- [FAQ and troubleshoot](https://learn.microsoft.com/azure/developer/azure-developer-cli/troubleshoot?tabs=Browser) for azd.
