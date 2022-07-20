targetScope = 'resourceGroup'

// PARAMETERS
param location string = resourceGroup().location
param tags object = {}

// PARAMETERS Scaleset
param vmss_name string 
param vmss_instance_type string = 'Standard_B1s'
param vmss_instance_count int
param vmss_osdisk_type string = 'Standard_LRS'
@description('If automatic OS upgrade is required a supported image must be used (https://docs.microsoft.com/en-us/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-automatic-upgrade)')
param vmss_image_reference object =  {
  publisher: 'Canonical'
  offer: '0001-com-ubuntu-server-focal'
  sku: '20_04-lts-gen2'
  version: 'latest'
}
param vmss_subnet_id string
param vmss_extensions array = []
@secure()
param vmss_admin_password string = ''
param vmss_admin_username string
param vmss_diag_storage_account_name string = ''
param vmss_enable_system_assigned_identity bool = false

// PARAMETERS Container
param container_image string
param container_name string = 'azure-url-monitor'
param container_environment object
param container_extra_hosts object = {}

// VARIABLES
var _vmss_extensions = concat(vmss_extensions, [
  {
    name: 'healthRepairExtension'
    properties: {
        autoUpgradeMinorVersion: true
        publisher: 'Microsoft.ManagedServices'
        type: 'ApplicationHealthLinux'
        typeHandlerVersion: '1.0'
        settings: {
            protocol: 'tcp'
            port: 22
        }
    }
  }
])

var _docker_compose = {
  version: '3'
  services: {
    azure_url_monitor: {
        image: container_image
        container_name: container_name
        restart: 'unless-stopped'
        environment: container_environment
        extra_hosts: container_extra_hosts
        network_mode: 'host'
    }
  }
}
  
var _cloud_init_tpl = loadTextContent('cloud-init.yaml.tpl', 'utf-8')
var _cloud_init_base64 = base64(format(_cloud_init_tpl, _docker_compose))
var _vmss_diag_storage_account_uri = empty(vmss_diag_storage_account_name) ? vmss_diag_storage_account_name :  'https://${vmss_diag_storage_account_name}.blob.${environment().suffixes.storage}'
var _dpl_base_rnd_full = uniqueString(vmss_name)
var _secret_extras = '!(@#$[%+)=-_^]'
var _rgid_rnd_take = min(length(resourceGroup().id) % length(_secret_extras), 4)
var _vmss_admin_password = empty(vmss_admin_password) ? '${take(toUpper(_dpl_base_rnd_full), 4)}/${_dpl_base_rnd_full}/${take(_secret_extras, _rgid_rnd_take)}' : vmss_admin_password

// RESOURCES
resource vmss 'Microsoft.Compute/virtualMachineScaleSets@2021-04-01' = {
  name: vmss_name
  tags: tags
  location: location
  identity: vmss_enable_system_assigned_identity ? {
    type: 'SystemAssigned'
  }: null
  sku: {
    capacity: vmss_instance_count
    name: vmss_instance_type
    tier: 'standard'
  }
  properties: {
    overprovision: false
    upgradePolicy:  {
      automaticOSUpgradePolicy: {
        enableAutomaticOSUpgrade: true
        disableAutomaticRollback: false
      } 
      mode: 'Rolling'
    }
    virtualMachineProfile: {
      osProfile: {
        computerNamePrefix: vmss_name
        adminUsername: vmss_admin_username
        adminPassword: _vmss_admin_password
        customData: _cloud_init_base64
        linuxConfiguration: {
          disablePasswordAuthentication: false
          provisionVMAgent: true
        }
      }
      storageProfile: {
        imageReference: vmss_image_reference
        osDisk: {
          osType: 'Linux'
          diskSizeGB: 32
          createOption: 'FromImage'
          managedDisk: {
            storageAccountType: vmss_osdisk_type
          }
        }
      }
      networkProfile: {
        networkInterfaceConfigurations:  [{
          name: 'nic-${vmss_name}'
          properties: {
            primary: true
            ipConfigurations: [
            {
                name: 'ipconfig0'
                properties: {
                  primary: true
                  subnet: {
                    id: vmss_subnet_id
                  }
                  privateIPAddressVersion: 'IPv4'
                }
                
              }
            ]
          }
        }]
      }
      diagnosticsProfile: {
        bootDiagnostics: {
          enabled: empty(_vmss_diag_storage_account_uri) ? false : true
          storageUri: _vmss_diag_storage_account_uri
        }
      }
      extensionProfile: {
        extensions: _vmss_extensions
      }
    }
    automaticRepairsPolicy:{
      enabled: true
      gracePeriod: 'PT10M'
    }
  }
}
