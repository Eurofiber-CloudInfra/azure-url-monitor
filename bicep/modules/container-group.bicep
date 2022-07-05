targetScope = 'resourceGroup'

param location string 
param tags object
param container_name string = 'azure-url-monitor'

@secure()
@description('Instrumentation key of the Application Inisght instance')
param ai_instrumentation_key string

@description('Full url to the postman exported collection json file or shared collection')
param postman_collection_url string

@description('Container image name. (eg ghcr.io/eurofiber-cloudinfra/azure-url-monitor:latest)')
param container_image string

@description('Subnet id of the for private Container Instance deployment. The subnet must have service delegation set to "Microsoft.ContainerInstance/containerGroups"')
param container_subnet_id string = ''

param container_cpu_cores string = '0.25'
param container_memory_gb string = '0.25'

@description('Resource Id of the Log Analytics Workspace')
param log_id string

@allowed([
  'Always'
  'Never'
  'OnFailure'
])
param restart_policy string = 'Always'

var _subnet_id = (empty(container_subnet_id)) ? [] : [{ id: container_subnet_id }]

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
              value: ai_instrumentation_key
            }
            {
              name: 'PM_COLLECTION_URL'
              value: postman_collection_url
            }
            {
              name: 'TEST_FREQUENCY_MINUTES'
              value: '1'
            }    
          ]
          resources: {
            requests: {
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

output id string = container_group.id
output container_name string = container_name
output rg_name string = resourceGroup().name
