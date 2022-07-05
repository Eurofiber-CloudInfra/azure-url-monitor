targetScope = 'resourceGroup'

param container_group_id string
param tags object
param alert_name string = 'Azure URL Monitor Container Restarted'

resource alert 'Microsoft.Insights/activityLogAlerts@2020-10-01' = {
  name: alert_name
  location: 'Global'
  tags: tags
  properties: {
    condition: {
      allOf: [
        {
          field: 'category'
          equals: 'Administrative'
        }
        {
          field: 'operationName'
          equals: 'Microsoft.ContainerInstance/containerGroups/restart/action'
        }
      ]
    }
    scopes: [
      container_group_id 
    ]
    actions: {
      actionGroups: []
    }
    enabled: true
  }
}
