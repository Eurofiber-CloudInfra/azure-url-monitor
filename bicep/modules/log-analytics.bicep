targetScope  =  'resourceGroup'

param location string
param tags object
param sku string = 'PerGB2018'

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

output id string = log.id
