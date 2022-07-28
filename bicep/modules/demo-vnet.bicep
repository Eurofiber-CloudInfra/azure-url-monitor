targetScope = 'resourceGroup'

// PARAMETERS
param location string 
param tags object

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
    subnets:  [ 
      { 
        name: 'container-instances'
        properties: {
          addressPrefix: '10.0.0.0/24'
          delegations: [ 
            {
              name: 'aci-subnet-delegation'
              properties: {
                serviceName: 'Microsoft.ContainerInstance/containerGroups'
              }
            }
          ]
        }
      }
      { 
        name: 'virtual-machine_scale-set'
        properties: {
          addressPrefix: '10.0.1.0/24'
        }
      }   
    ]
  }
}

// OUTPUTS
output container_subnet_id string = vnet.properties.subnets[0].id
output vmss_subnet_id string = vnet.properties.subnets[1].id
