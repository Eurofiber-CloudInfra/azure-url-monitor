targetScope = 'subscription'

param location string = deployment().location
param tags object

param app_name string
param name_base string


var _name_base = format(name_base, app_name)

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-${_name_base}'
  location: location
  tags: tags
}

module log 'modules/log-analytics.bicep' = {
  scope: rg
  name: 'log-${_name_base}'
  params: {
    location: location
    tags: tags
  }
}

module ai 'modules/application-insghts.bicep' = {
  scope: rg
  name: 'ai-${_name_base}'
  params: {
    location: location
    log_id: log.outputs.id
    tags: tags
  }
}

module alert 'modules/availability-metric-alert.bicep' = {
  scope: rg
  name: 'alert-${_name_base}'
  params: {
    application_insights_id: ai.outputs.id
    alert_name: 'Availability Test Failed For ${toUpper(app_name)}'
    location: location
  }
}

output instrumentation_key string = ai.outputs.instrumentation_key
