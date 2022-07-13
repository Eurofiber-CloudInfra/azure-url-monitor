targetScope = 'resourceGroup'

// /subscriptions/815c9830-647b-484e-a16b-8d3d67c7a09e/resourceGroups/rg-demoapp-tst-001/providers/Microsoft.ContainerInstance/containerGroups/ci-demoapp-tst-001
param ci_name string ='ci-demoapp-tst-001'
param ci object
param log_id string = ''
param ci_index int = 0


var ci_c = {
    name: 'azure-url-monitor'
    properties: {
    image: 'ghcr.io/eurofiber-cloudinfra/azure-url-monitor:43'
    environmentVariables: [
        {
            name: 'AI_INSTRUMENTATION_KEY'
            value: '93a59115-1e1a-4c4b-9c03-8c7b609440fb'
        }
        {
            name: 'PM_COLLECTION_URL'
            value: 'https://www.getpostman.com/collections/caa66e30322537554be0'
        }
        {
            name: 'TEST_FREQUENCY_MINUTES'
            value: '2'
        }
    ]
  }
}

resource ci_update 'Microsoft.Resources/deployments@2021-04-01' = {
  name: 'ci-update'
  properties: {
    mode: 'Incremental'
    expressionEvaluationOptions: {
      scope: 'Inner'
    }
    template: {
      '$schema': 'https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        ci: {
          type: 'object'
        }
        ci_c: {
          type: 'object'
        }
        ci_name: {
          type: 'string'
        }
        log_id: {
          type: 'string'
        }
      }
      variables: {}
      resources: [
        {
          type: 'Microsoft.ContainerInstance/containerGroups'
          name: ci_name
          apiVersion: '2021-10-01'
          location: resourceGroup().location
          properties: {
            containers: [{
              name: 'azure-url-monitor'
              properties: {
              image: 'ghcr.io/eurofiber-cloudinfra/azure-url-monitor:43'
              environmentVariables: [
                  {
                      name: 'AI_INSTRUMENTATION_KEY'
                      value: '93a59115-1e1a-4c4b-9c03-8c7b609440fb'
                  }
                  {
                      name: 'PM_COLLECTION_URL'
                      value: 'https://www.getpostman.com/collections/caa66e30322537554be0'
                  }
                  {
                      name: 'TEST_FREQUENCY_MINUTES'
                      value: '2'
                  }
              ]
              resources: ci.properties.containers[0].properties.resources
            }}]
            osType: ci.properties.osType
            restartPolicy: ci.properties.restartPolicy
            sku: ci.properties.sku
            subnetIds: ci.properties.subnetIds
            diagnostics: empty(log_id) ? {}: {
              logAnalytics: {
                logType: 'ContainerInstanceLogs'
                workspaceResourceId: log_id
                workspaceKey: listKeys(log_id, '2021-12-01-preview').primarySharedKey
                workspaceId: reference(log_id, '2021-12-01-preview').customerId
              }
            }
          }
        }
      ]
      outputs: {}
    }
    parameters: {
      ci: {
        value: ci
      }
      ci_c: {
        value: ci_c
      }
      ci_name: {
        value: ci_name
      }
      log_id: {
        value: log_id
      }
    }
  }
}
