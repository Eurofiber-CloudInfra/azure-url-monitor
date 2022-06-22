targetScope = 'subscription'

param location string = deployment().location
param name_base string = 'urlmonitor-tst-euwe-005'
param tags object = {
  'owner': 'dennis'
}

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: 'rg-${name_base}'
  location: location
  tags: tags
}

module ai 'modules/application-insghts.bicep' = {
  scope: rg
  name: 'ai'
  params: {
    location: location
    name_base: name_base
    tags: tags
  }
}

output instrumentation_key string = ai.outputs.instrumentation_key
