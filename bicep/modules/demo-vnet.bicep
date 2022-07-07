targetScope = 'resourceGroup'

// PARAMETERS
param location string 
param tags object

// VARIABLES
var _subnets = [
  {
    name: 'container-instances'
    prefix: '10.0.0.0/24'
  }
]

// RESOURCES
resource vnet 'Microsoft.Network/virtualNetworks@2020-06-01' = {
  name: deployment().name
  location: location 
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets:  [for (subnet, idx) in _subnets: { 
      name: subnet.name
      properties: {
        addressPrefix: subnet.prefix
        delegations: [
          {
            name: 'aci-subnet-delegation'
            properties: {
              serviceName: 'Microsoft.ContainerInstance/containerGroups'
            }
          }
        ]
      }
    }]
  }
}

// OUTPUTS
output container_subnet_id string = vnet.properties.subnets[0].id
