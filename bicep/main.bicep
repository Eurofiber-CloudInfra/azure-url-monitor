targetScope = 'subscription'

// PARAMETERS
param location string = deployment().location
param tags object = {
  application: 'azure url monitor'
  environment: 'demo'
}
param app_name string = 'demoapp'
param name_base string = '{0}-tst-001'
param postman_collection_url string = 'https://www.getpostman.com/collections/1d497e3f38536a136bb0'
param container_image string = 'ghcr.io/eurofiber-cloudinfra/azure-url-monitor:43'
param container_subnet_id string = ''
param deploy_demo_vnet bool = true

// VARIABLES
var _name_base = format(name_base, app_name)
var _container_subnet_id = (deploy_demo_vnet) ? vnet.outputs.container_subnet_id : container_subnet_id

// RESOURCES
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

module appi 'modules/application-insghts.bicep' = {
  scope: rg
  name: 'appi-${_name_base}'
  params: {
    location: location
    tags: tags
    log_id: log.outputs.id
  }
}

module vnet 'modules/demo-vnet.bicep' = if (deploy_demo_vnet) {
  name: 'vnet-${_name_base}'
  scope: rg
  params: {
    location: location
    tags: tags
  }
}

module ci 'modules/container-group.bicep' = {
  scope: rg
  name: 'ci-${_name_base}'
  params: {
    location: location
    tags: tags
    container_image: container_image
    ai_instrumentation_key: appi.outputs.instrumentation_key
    postman_collection_url: postman_collection_url
    log_id: log.outputs.id
    container_subnet_id: _container_subnet_id
  }
}

module alert_failed_test 'modules/alert-failed-test.bicep' = {
  scope: rg
  name: 'alert-failed-test-${_name_base}'
  params: {
    tags: tags
    application_insights_id: appi.outputs.id
    alert_name: 'Web Availability Test Failed for ${toUpper(app_name)}'
  }
}

module alert_container_restart 'modules/alert-container-restart2.bicep' = {
  scope: rg
  name: 'alert-container-restart-${_name_base}'
  params: {
    location: location
    tags: tags
    log_id: log.outputs.id
    ci_rg_name: ci.outputs.rg_name 
    ci_name: ci.name
    container_name: ci.outputs.container_name
  }
}
