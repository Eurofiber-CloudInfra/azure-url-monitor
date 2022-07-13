targetScope = 'subscription'

param ci_name string = 'ci-demoapp-tst-001'
param ci_rg_name string = 'rg-demoapp-tst-001'
param log_id string = '/subscriptions/815c9830-647b-484e-a16b-8d3d67c7a09e/resourcegroups/rg-demoapp-tst-002/providers/microsoft.operationalinsights/workspaces/log-demoapp-tst-002'

resource ci_resource 'Microsoft.ContainerInstance/containerGroups@2021-10-01' existing = {
  name: ci_name
  scope: resourceGroup(ci_rg_name)
}


module ci_updater 'modules/container-group-configurator.bicep' = {
  scope: resourceGroup(ci_rg_name)
  name: 'ci-updater'
  params: {
    ci: ci_resource
    log_id: log_id
  }
}
output  ci object = ci_resource.properties
