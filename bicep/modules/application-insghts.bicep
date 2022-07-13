targetScope = 'resourceGroup'

// PARAMETERS
param location string 
param tags object 

@description('Log Analytics Workspace resource id where the Application Insights instance stores its test results')
param log_id string

// RESOURCES
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

// OUTPUTS
output id string = ai.id
output instrumentation_key string = ai.properties.InstrumentationKey
