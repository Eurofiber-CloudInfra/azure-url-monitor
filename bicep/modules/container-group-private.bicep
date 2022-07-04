targetScope = 'resourceGroup'

param location string 
param tags object

@secure()
param ai_instrumentation_key string
param postman_collection_url string
param container_image string 

param container_subnet_id string = ''

@description('The number of CPU cores to allocate to the container.')
param cpu_cores int = 1

@description('The amount of memory to allocate to the container in gigabytes.')
param memory_gb int = 1

param log_id string

@allowed([
  'Always'
  'Never'
  'OnFailure'
])
param restart_policy string = 'Always'

resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2021-09-01' = {
  name: deployment().name
  location: location
  tags: tags
  properties: {
    subnetIds: [
      {
        id: container_subnet_id
      } 
    ]
    containers: [
      {
        name: 'azure-url-monitor'
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
          // a port must be specified
          ports: [
            {
              port: 80
            }
           ]
          resources: {
            requests: {
              cpu: cpu_cores
              memoryInGB: memory_gb
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
    ipAddress: {
      type: 'Private'
      // a port must be specified
      ports: [
        {
          port: 80
        }
      ]
    }
  }
}
