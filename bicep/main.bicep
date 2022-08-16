targetScope = 'subscription'

/*

This is an example deployment that will setup and configure all necessary resources in your environment to test the Azure URL Monitor container. 
The container can be deployed as an Container Instance or on Virtual Machine Scale Set by using the `deployment_mode` parameter.
It is prepared to deploy with the parameter default values but feel free to adjust it to suit your environment.

*/

// PARAMETERS
param location string = deployment().location
param tags object = {}
@allowed([
  'container_instance'
  'virtual_machine_scale_set'
])
param deployment_mode string = 'container_instance'
@description('''
  Subnet resource id for the deployment. When `deployment_mode` is set to `container_instance`  this subnet must have service delegation set to `Microsoft.ContainerInstance/containerGroups`.
  For a demo deployment this paramater can be left empty, an example VNET will be created.
''')
param subnet_id string = ''

@description('Switch to deploy a demo vnet when no `subnet_id` paramater is provided')
param deploy_demo_vnet bool = empty(subnet_id) ? true: false

@description('Application name that the Azure URL monitor will be monitoring')
param app_name string = 'demoapp'

@description('Resource Id of the Log Analytics Workspace that will be attached to the Application Instance instance. When left empty one will be created.')
param log_analytics_workspace_id string = ''

// PARAMETERS: Resource Naming
@description('Resource naming base template. Uses {0} for resource abbreviation and {1} for the application name')
param name_base string = '{0}-{1}-tst-001'
param rg_name string = format(name_base, 'rg', app_name)
param log_name string = format(name_base, 'log', app_name)
param appi_name string = format(name_base, 'appi', app_name)
param vnet_name string = format(name_base, 'vnet', app_name)
param ci_name string = format(name_base, 'ci', app_name)
param vmss_name string = format(name_base, 'vmss', app_name)

// PARAMETERS: Virtual Machine Scale Set
param vmss_instance_count int = 1
@secure()
@description('Local vmss admin password, when left empty a random password will be generated in the vmss module')
param vmss_admin_password  string = ''
param vmss_admin_username string = 'monitor-admin'
param vmss_diag_storage_account_name string = ''
param vmss_enable_system_assigned_identity bool = false

// PARAMETERS: Container Instance
param ci_enable_system_assigned_identity bool = false

// PARAMETERS: Url Monitor Container 
@description('Azure URL Monitor image name')
param container_image string = 'ghcr.io/eurofiber-cloudinfra/azure-url-monitor:latest'

@description('URL to the Postman Collection file. By default it uses a demo collection with one successful and one failing request')
param postman_collection_url string = 'https://www.getpostman.com/collections/772cbe72da0c0f2f0fb4'

@description('Test frequency of the Postman collection in minutes')
param test_frequency_minutes int = 1

@description('Newman collection run timeout in ms')
param nm_timeout_collection int = 300000

@description('Newman request timeout in ms')
param nm_timeout_request int = 5000

@description('Newman script timeout in ms')
param nm_timeout_script int = 5000

@description('Enable/disable certificate validation. When enabled the test will fail if the certificate is not valid.')
param certificate_validation_check bool = true

@description('Enable/disable certificate failure when encountering self-signed certificates.')
param certificate_ignore_self_signed bool = false

@description('Enable/disable certificate expiration check. When enabled the test will fail if certificate expires with the number of days specified in CERTIFICATE_EXPIRATION_DAYS')
param certificate_check_expiration bool = true

@description('Number of days before the certificate will expire.')
param certificate_expiration_gracetime_days int = 14

@description('Name of the test location shown in Application Inights, when left empty it defaults to the ip address of the container')
param monitor_location string = ''

@description('''
  Used only in VMSS deployment! Specify custom ip host mappings to override default container resolve behaviour. eg: 
  {
    'somehost.example.com': '10.1.1.1'
    'otherhost.example.com': '10.2.2.2'
  }
''')
param container_extra_hosts object = {}

// PARAMETERS: Application Insights Alerts
param alert_failed_test_name string = format(name_base, 'alert-failed-test', app_name)
param alert_failed_test_displayname string = 'Availability Test Failed for ${toUpper(app_name)}'
param alert_no_data_received_name string = format(name_base, 'alert-no-data', app_name)
param alert_no_data_received_displayname string = 'No Data Received from URL Monitor'

// VARIABLES
var _ci_subnet_id = deploy_demo_vnet && empty(subnet_id) ? vnet.outputs.container_subnet_id : subnet_id
var _vmss_subnet_id = deploy_demo_vnet && empty(subnet_id) ? vnet.outputs.vmss_subnet_id : subnet_id
var _log_id = empty(log_analytics_workspace_id) ? log.outputs.id : log_analytics_workspace_id
var _container_environment = {
  AI_INSTRUMENTATION_KEY: appi.outputs.instrumentation_key
  PM_COLLECTION_URL: postman_collection_url
  TEST_FREQUENCY_MINUTES: string(test_frequency_minutes)
  LOCATION: monitor_location
  NM_TIMEOUT_COLLECTION: string(nm_timeout_collection)
  NM_TIMEOUT_REQUEST: string(nm_timeout_request)
  NM_TIMEOUT_SCRIPT: string(nm_timeout_script)
  CERTIFICATE_VALIDATION_CHECK: toUpper(string(certificate_validation_check))
  CERTIFICATE_IGNORE_SELF_SIGNED: toUpper(string(certificate_ignore_self_signed))
  CERTIFICATE_CHECK_EXPIRATION: toUpper(string(certificate_check_expiration))
  CERTIFICATE_EXPIRATION_GRACETIME_DAYS: string (certificate_expiration_gracetime_days)
}

// RESOURCES
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rg_name
  location: location
  tags: tags
}

module log 'modules/log-analytics.bicep' = if (empty(log_analytics_workspace_id)) {
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
    log_id: _log_id
  }
}

module vnet 'modules/demo-vnet.bicep' = if (deploy_demo_vnet) {
  name: vnet_name
  scope: rg
  params: {
    location: location
    tags: tags
  }
}

module ci 'modules/container-group.bicep' = if (deployment_mode == 'container_instance') {
  scope: rg
  name: ci_name
  params: {
    location: location
    tags: tags
    log_id: _log_id
    ci_enable_system_assigned_identity: ci_enable_system_assigned_identity
    ci_subnet_id: _ci_subnet_id
    container_image: container_image
    container_environment: _container_environment
  }
}

module vmss 'modules/virtual-machine-scale-set.bicep' = if (deployment_mode == 'virtual_machine_scale_set') {
  scope: rg
  name: vmss_name
  params: {
    location: location
    tags: tags
    vmss_admin_username: vmss_admin_username
    vmss_admin_password: vmss_admin_password
    vmss_instance_count: vmss_instance_count
    vmss_diag_storage_account_name: vmss_diag_storage_account_name
    vmss_enable_system_assigned_identity: vmss_enable_system_assigned_identity
    vmss_subnet_id: _vmss_subnet_id
    container_image: container_image
    container_environment: _container_environment
    container_extra_hosts: container_extra_hosts
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

module alert_no_data_received 'modules/alert-no-data-received.bicep' = {
  scope: rg
  name: alert_no_data_received_name
  params: {
    location: location
    tags: tags
    application_insights_id: appi.outputs.id
    alert_displayname: alert_no_data_received_displayname
  }
}
