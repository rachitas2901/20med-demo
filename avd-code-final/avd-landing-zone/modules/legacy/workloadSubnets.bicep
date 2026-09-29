param vnetName string
param avdSubnetName string = 'snet-avd'
param managementSubnetName string = 'snet-management'
param avdSubnetPrefix string
param managementSubnetPrefix string
param avdNsgId string
param managementNsgId string
param routeTableId string

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: vnetName
}

resource avdSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: vnet
  name: avdSubnetName
  properties: {
    addressPrefix: avdSubnetPrefix
    networkSecurityGroup: {
      id: avdNsgId
    }
    routeTable: {
      id: routeTableId
    }
    privateEndpointNetworkPolicies: 'Enabled'
    serviceEndpoints: [
      {
        service: 'Microsoft.Storage'
      }
    ]
  }
}

resource managementSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: vnet
  name: managementSubnetName
  properties: {
    addressPrefix: managementSubnetPrefix
    networkSecurityGroup: {
      id: managementNsgId
    }
    routeTable: {
      id: routeTableId
    }
  }
}

output avdSubnetId string = avdSubnet.id
output managementSubnetId string = managementSubnet.id
