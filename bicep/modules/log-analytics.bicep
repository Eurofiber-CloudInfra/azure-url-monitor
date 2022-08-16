targetScope  =  'resourceGroup'

// PARAMETERS
param location string
param tags object
param sku string = 'PerGB2018'


param solutions array = [
  'ApplicationInsights'
  'ContainerInsights'
]

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

resource log_solution 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = [for log_solution_type in solutions: {
  name: '${log_solution_type}(${log.name})'
  location: location
  tags: tags
  plan: {
    name: '${log_solution_type}(${log.name})'
    product: 'OMSGallery/${log_solution_type}'
    promotionCode: ''
    publisher: 'Microsoft'
  }
  properties: {
    workspaceResourceId: log.id
  }
}]

// OUTPUTS
output id string = log.id
