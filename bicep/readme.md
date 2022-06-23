
# Introduction
Deploys a complete set of resources to take the url monitor for a spin. Resources deployed:
- Log Analytics Workspace
- Application Insights Instance
- Availability Alert Rule

TODO: add container instance deployment

# Deployment

Change the `main.paramaters.json` file to add your application name and resource naming preference, than execute the commands below.

```
 $ az login
 $ az account set --subscription <YOUR SUBSCRIPTION ID> 
 $ az deployment sub create --location <YOUR LOCATION> --template-file bicep/main.bicep --parameters main.parameters.json

```