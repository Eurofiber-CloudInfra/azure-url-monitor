targetScope = 'resourceGroup'

// PARAMETERS
param location string 
param tags object
param container_name string = 'azure-url-monitor'

@description('Container image name. (eg ghcr.io/eurofiber-cloudinfra/azure-url-monitor:latest)')
param container_image string

@description('''
  Subnet id for the private Container Instance deployment. The subnet must have service delegation set to "Microsoft.ContainerInstance/containerGroups".
  When left empty the Container Instance will run in an Azure defined private space which will not be able to communicate to your internal network.  
''')
param ci_subnet_id string
param ci_cpu_cores string 
param ci_memory_gb string

param container_environment object

@description('Resource Id of the Log Analytics Workspace')
param log_id string

@allowed([
  'Always'
  'Never'
  'OnFailure'
])
param restart_policy string = 'Always'

// VARIABLES
var _subnet_id = (empty(ci_subnet_id)) ? [] : [{ id: ci_subnet_id }]

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
          environmentVariables: [ for item in items(container_environment): {
            name: item.key
            value: item.value
          }]
          resources: {
            requests: {
              cpu: json(ci_cpu_cores)
              memoryInGB: json(ci_memory_gb)
            }
            limits: {
              cpu: json(ci_cpu_cores)
              memoryInGB: json(ci_memory_gb)             
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
