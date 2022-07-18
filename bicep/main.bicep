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

@description('Resource name for the Resource Group')
param rg_name string = format(name_base, 'rg', app_name)

@description('Resource name for the Log Anaytics Workspace')
param log_name string = format(name_base, 'log', app_name)

@description('Resource name for the Applications Insights Instance')
param appi_name string = format(name_base, 'appi', app_name)

@description('Resource name for demo Vnet')
param vnet_name string = format(name_base, 'vnet', app_name)

@description('Resource name for Container Instance')
param ci_name string = format(name_base, 'ci', app_name)

@description('The CPU request and limit of this container instance')
param container_cpu_cores string = '0.5'

@description('The The memory request  and limit in GB of this container instance')
param container_memory_gb string = '0.5'

@description('Test frequency of the Postman collection in minutes')
param test_freuency_minutes int = 1

@description('Resource name for no data alert')
param alert_no_data_received_name string = format(name_base, 'alert-no-data', app_name)

@description('Display name for no data alert')
param alert_no_data_received_displayname string = 'No monitoring data received from URL monitor'


@description('Resource name for failed test alert')
param alert_failed_test_name string = format(name_base, 'alert-failed-test', app_name)

@description('Display name for failed test alert')
param alert_failed_test_displayname string = 'Availability Test Failed for ${toUpper(app_name)}'

@description('Resource name for container restart  alert')
param alert_container_restart_name string = format(name_base, 'alert-container-restart', app_name)

@description('Display name for container restart  alert')
param alert_container_restart_displayname string = 'Azure URL Monitor Container Restarted'

@description('URL to the Postman Collection file. By default it uses a demo collection with one successful and one failing request')
param postman_collection_url string = 'https://www.getpostman.com/collections/772cbe72da0c0f2f0fb4'


@description('Azure URL Monitor image name')
param container_image string = 'ghcr.io/eurofiber-cloudinfra/azure-url-monitor:latest'

@description('''
  Subnet id for the Container Instance deployment. The subnet must have service delegation set to "Microsoft.ContainerInstance/containerGroups".
  For a demo deployment this paramater can be left empty and use the "deploy_demo_vnet" parameter to handle demo vnet/subnet creation
''')
param container_subnet_id string = ''

@description('Switch to deploy a demo vnet with a delegated subnet for the Container Instance. Must be set to "false" when a container_subnet_id is provided')
param deploy_demo_vnet bool = true

// VARIABLES
var _container_subnet_id = deploy_demo_vnet && empty(container_subnet_id) ? vnet.outputs.container_subnet_id : container_subnet_id

// RESOURCES
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rg_name
  location: location
  tags: tags
}

module log 'modules/log-analytics.bicep' = {
  scope: rg
  name: log_name
  params: {
    location: location
    tags: tags
  }
}

module appi 'modules/application-insghts.bicep' = {
  scope: rg
  name: appi_name
  params: {
    location: location
    tags: tags
    log_id: log.outputs.id
  }
}

module vnet 'modules/demo-vnet.bicep' = if (deploy_demo_vnet && empty(container_subnet_id)) {
  name: vnet_name
  scope: rg
  params: {
    location: location
    tags: tags
  }
}

module ci 'modules/container-group.bicep' = {
  scope: rg
  name: ci_name
  params: {
    location: location
    tags: tags
    container_image: container_image
    ai_instrumentation_key: appi.outputs.instrumentation_key
    postman_collection_url: postman_collection_url
    log_id: log.outputs.id
    container_subnet_id: _container_subnet_id
    container_cpu_cores: container_cpu_cores
    container_memory_gb: container_memory_gb
    test_freuency_minutes: test_freuency_minutes
  }
}

module alert_failed_test 'modules/alert-failed-test.bicep' = {
  scope: rg
  name: alert_failed_test_name
  params: {
    tags: tags
    application_insights_id: appi.outputs.id
    alert_displayname: alert_failed_test_displayname
  }
}

module alert_container_restart 'modules/alert-container-restart.bicep' = {
  scope: rg
  name: alert_container_restart_name
  params: {
    location: location
    tags: tags
    log_id: log.outputs.id
    alert_displayname: alert_container_restart_displayname
    ci_rg_name: ci.outputs.rg_name 
    ci_name: ci.name
    container_name: ci.outputs.container_name
  }
}

module alert_no_data_received 'modules/alert-no-data-received.bicep' = {
  scope: rg
  name: alert_no_data_received_name
  params: {
    location: location
    tags: tags
    alert_displayname: alert_no_data_received_displayname
    application_insights_id: appi.outputs.id
  }
}
