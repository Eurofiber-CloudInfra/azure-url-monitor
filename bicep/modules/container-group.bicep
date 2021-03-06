targetScope = 'resourceGroup'

// PARAMETERS
param location string 
param tags object
param container_name string = 'azure-url-monitor'

@secure()
@description('Instrumentation key of the Application Inisght instance')
param ai_instrumentation_key string

@description('Full url to the postman exported collection json file or shared collection')
param postman_collection_url string

@description('Timeout in miliseonds for the execution of the Postman collection ')
param collection_timeout_miliseconds int = 300000

@description('Timeout in miliseonds for the execution of a single Postman collection request')
param request_timeout_miliseconds int = 5000

@description('Timeout in miliseonds for the execution of a single Postman collection request script')
param script_timeout_miliseconds int = 5000

@description('Frequency in minutes')
param test_freuency_minutes int

@description('Container image name. (eg ghcr.io/eurofiber-cloudinfra/azure-url-monitor:latest)')
param container_image string

@description('''
  Subnet id for the private Container Instance deployment. The subnet must have service delegation set to "Microsoft.ContainerInstance/containerGroups".
  When left empty the Container Instance will run in an Azure defined private space which will not be able to communicate to your internal network.  
''')
param container_subnet_id string

param container_cpu_cores string 
param container_memory_gb string

@description('Resource Id of the Log Analytics Workspace')
param log_id string

@allowed([
  'Always'
  'Never'
  'OnFailure'
])
param restart_policy string = 'Always'

// VARIABLES
var _subnet_id = (empty(container_subnet_id)) ? [] : [{ id: container_subnet_id }]

// RESOURCES
resource container_group 'Microsoft.ContainerInstance/containerGroups@2021-09-01' = {
  name: deployment().name
  location: location
  tags: tags
  properties: {
    subnetIds: _subnet_id
    containers: [
      {
        name: container_name
        properties: {
          image: container_image
          environmentVariables: [
            {
              name: 'AI_INSTRUMENTATION_KEY'
              secureValue: ai_instrumentation_key
            }
            {
              name: 'PM_COLLECTION_URL'
              value: postman_collection_url
            }
            {
              name: 'TEST_FREQUENCY_MINUTES'
              value: string(test_freuency_minutes)
            }
            {
              name: 'NM_TIMEOUT_COLLECTION'
              value: string(collection_timeout_miliseconds)
            }
            {
              name: 'NM_TIMEOUT_REQUEST'
              value: string(request_timeout_miliseconds)
            }
            {
              name: 'NM_TIMEOUT_SCRIPT'
              value: string(script_timeout_miliseconds)
            }
          ]
          resources: {
            requests: {
              cpu: json(container_cpu_cores)
              memoryInGB: json(container_memory_gb)
            }
            limits: {
              cpu: json(container_cpu_cores)
              memoryInGB: json(container_memory_gb)             
            }
          }
        }
      }
    ]
    diagnostics: {
      logAnalytics: {
        logType: 'ContainerInstanceLogs'
        workspaceResourceId: log_id
        workspaceKey: listKeys(log_id, '2021-12-01-preview').primarySharedKey
        workspaceId: reference(log_id, '2021-12-01-preview').customerId
      }
    }
    osType: 'Linux'
    restartPolicy: restart_policy
  }
}

// OUTPUTS
output id string = container_group.id
output container_name string = container_name
output rg_name string = resourceGroup().name
