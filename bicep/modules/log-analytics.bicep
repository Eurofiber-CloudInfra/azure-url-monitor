targetScope  =  'resourceGroup'

// PARAMETERS
param location string
param tags object
param sku string = 'PerGB2018'

// RESOURCES
resource log 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: deployment().name
  location: location
  tags: tags
  properties: {
   sku: {
    name: sku
   }
   retentionInDays: 30
  }
}

// OUTPUTS
output id string = log.id
