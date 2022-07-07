/*

This is an example deployment that will setup and configure all necessary resources in your environment to test the Azure URL Monitor. 
It is prepared to deploy with the parameter default values but feel free to adjust it to suite your environment.

*/

targetScope = 'subscription'

// PARAMETERS
param location string = deployment().location
param tags object = {
  application: 'azure url monitor'
  environment: 'demo'
}

@description('Application name that the Azure URL monitor will be monitoring')
param app_name string = 'demoapp'

@description('Resource naming base template. Uses {0} for resource abbreviation and {1} for the application name')
param name_base string = '{0}-{1}-tst-001'

@description('URL to the Postman Collection file. By default it uses a demo collection with one successful and one failing request')
param postman_collection_url string = 'https://www.getpostman.com/collections/1d497e3f38536a136bb0'

@description('Azure URL Monitor image name')
param container_image string = 'ghcr.io/eurofiber-cloudinfra/azure-url-monitor:latest'

@description('''
  Subnet id for the Container Instance deployment. The subnet must have service delegation set to "Microsoft.ContainerInstance/containerGroups".
  For a demo deployment this paramater can be left empty and use the "deploy_demo_vnet" paramater to handle demo vnet/subnet creation
''')
param container_subnet_id string = ''

@description('Switch to deploy a demo vnet with a delegated subnet for the Container Instance. Must be set to "false" when a container_subnet_id is provided')
param deploy_demo_vnet bool = true

// VARIABLES
var _container_subnet_id = (deploy_demo_vnet) ? vnet.outputs.container_subnet_id : container_subnet_id

var _rg_name = format(name_base, 'rg', app_name)
var _log_name = format(name_base, 'log', app_name)
var _appi_name = format(name_base, 'appi', app_name)
var _vnet_name = format(name_base, 'vnet', app_name)
var _ci_name = format(name_base, 'ci', app_name)

var _alert_failed_test_name = format(name_base, 'alert-failed-test', app_name)
var _alert_failed_test_displayname = 'Availability Test Failed for ${toUpper(app_name)}'

var _alert_container_restart_name = format(name_base, 'alert-container-restart', app_name)
var _alert_container_restart_displayname= 'Azure URL Monitor Container Restarted'

// RESOURCES
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: _rg_name
  location: location
  tags: tags
}

module log 'modules/log-analytics.bicep' = {
  scope: rg
  name: _log_name
  params: {
    location: location
    tags: tags
  }
}

module appi 'modules/application-insghts.bicep' = {
  scope: rg
  name: _appi_name
  params: {
    location: location
    tags: tags
    log_id: log.outputs.id
  }
}

module vnet 'modules/demo-vnet.bicep' = if (deploy_demo_vnet) {
  name: _vnet_name
  scope: rg
  params: {
    location: location
    tags: tags
  }
}

module ci 'modules/container-group.bicep' = {
  scope: rg
  name: _ci_name
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
  name: _alert_failed_test_name
  params: {
    tags: tags
    application_insights_id: appi.outputs.id
    alert_displayname: _alert_failed_test_displayname
  }
}

module alert_container_restart 'modules/alert-container-restart.bicep' = {
  scope: rg
  name: _alert_container_restart_name
  params: {
    location: location
    tags: tags
    log_id: log.outputs.id
    alert_displayname: _alert_container_restart_displayname
    ci_rg_name: ci.outputs.rg_name 
    ci_name: ci.name
    container_name: ci.outputs.container_name
  }
}
