targetScope = 'subscription'

param location string = deployment().location
param tags object = {
  application: 'url monitor demo'
  environment: 'test'
}

param app_name string = 'myapp'
param name_base string = '{0}-tst-euno-001'
param postman_collection_url string = 'https://www.getpostman.com/collections/caa66e30322537554be0'
param container_image string = 'ghcr.io/eurofiber-cloudinfra/azure-url-monitor:develop'
param container_subnet_id string = ''

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
  }
}

// deploy demo vnet with subnet delegated to containerinstance service if no container subnet is specified
module demo_vnet 'modules/demo-vnet.bicep' = if (empty(container_subnet_id)) {
  name: 'vnet-${_name_base}'
  scope: rg
  params: {
    location: location
    tags: tags
  }
}

module aci 'modules/container-group-private.bicep' = {
  scope: rg
  name: 'aci-${_name_base}'
  params: {
    location: location
    tags: tags
    container_image: container_image
    ai_instrumentation_key: ai.outputs.instrumentation_key
    postman_collection_url: postman_collection_url
    log_id: log.outputs.id
    container_subnet_id: (empty(container_subnet_id)) ? demo_vnet.outputs.container_subnet_id : container_subnet_id
  }
}
