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

output instrumentation_key string = ai.properties.InstrumentationKey
