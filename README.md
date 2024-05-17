# QuoteOfTheDayAZD

### Prerequisites

- Clone the quote-of-the-day-dotnet repository: https://github.com/Azure-Samples/quote-of-the-day-dotnet
- Install Powershell if not already installed: https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7.4
- Install Azure CLI: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli
- Install & start Docker Desktop:  https://docs.docker.com/engine/install/

### Use Azure Developer CLI

This application can be run using the [Azure Developer CLI](https://aka.ms/azd), or `azd`, with very few commands:

- Install [azd](https://aka.ms/azure-dev/install).
- Log in `azd` (if you haven't done it before) to your Azure account:
```sh
azd auth login
```
- Create Azure resources and deploy the sample by running:
```sh
azd up
```
Notes:
  - The operation takes a few minutes the first time it is ever run for an environment.
  - At the end of the process, `azd` will display the `url` for the webapp. Follow that link to test the sample.
  - You can run `azd up` after saving changes to the sample to re-deploy and update the sample.
  - Report any issues to [azure-dev](https://github.com/Azure/azure-dev/issues) repo.
  - [FAQ and troubleshoot](https://learn.microsoft.com/azure/developer/azure-developer-cli/troubleshoot?tabs=Browser) for azd.