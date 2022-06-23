targetScope = 'resourceGroup'

param location string 
param tags object 
param log_id string

resource ai 'microsoft.insights/components@2020-02-02' = {
  name: deployment().name
  location: location
  tags: tags
  kind: 'web'
  properties: {
    DisableIpMasking: true
    Application_Type: 'web'
    RetentionInDays: 30
    WorkspaceResourceId: log_id
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

output id string = ai.id
output instrumentation_key string = ai.properties.InstrumentationKey
