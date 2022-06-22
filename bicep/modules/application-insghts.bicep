targetScope = 'resourceGroup'

param location string 
param name_base string 
param tags object 

resource ai 'microsoft.insights/components@2020-02-02' = {
  name: 'ai-${name_base}'
  location: location
  tags: tags
  kind: 'web'
  properties: {
    DisableIpMasking: true
    Application_Type: 'web'
    RetentionInDays: 30
    WorkspaceResourceId: log.id
    Flow_Type: 'Bluefield'
    Request_Source: 'Custom'
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource log 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: 'log-${name_base}'
  location: location
  tags: tags
  properties: {
   sku: {
    name: 'PerGB2018'
   } 
  }
}

param solutions array = [
  'ApplicationInsights'
]

resource law_solution 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = [for law_solution_type in solutions: {
  name: '${law_solution_type}(${log.name})'
  location: location
  tags: tags
  plan: {
    name: '${law_solution_type}(${log.name})'
    product: 'OMSGallery/${law_solution_type}'
    promotionCode: ''
    publisher: 'Microsoft'
  }
  properties: {
    workspaceResourceId: log.id
  }
}]


// resource law_solution 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' =  {
//   name: '${log.name}-ApplicationInsights'
//   location: location
//   tags: tags
//   plan: {
//     name: '${log.name}-ApplicationInsights'
//     product: 'OMSGallery/ApplicationInsights'
//     promotionCode: ''
//     publisher: 'Microsoft'
//   }
//   properties: {
//     workspaceResourceId: log.id
//   }
// }


output instrumentation_key string = ai.properties.InstrumentationKey
