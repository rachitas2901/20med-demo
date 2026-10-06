param vnetName string
param location string
param addressPrefix string
param firewallSubnetPrefix string
param firewallManagementSubnetPrefix string
param gatewaySubnetPrefix string
param tags object = {}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
  }
}

resource firewallSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: vnet
  name: 'AzureFirewallSubnet'
  properties: {
    addressPrefix: firewallSubnetPrefix
  }
}

resource firewallManagementSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: vnet
  name: 'AzureFirewallManagementSubnet'
  properties: {
    addressPrefix: firewallManagementSubnetPrefix
  }
}

resource gatewaySubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: vnet
  name: 'GatewaySubnet'
  properties: {
    addressPrefix: gatewaySubnetPrefix
  }
}

output vnetId string = vnet.id
output vnetName string = vnet.name
output firewallSubnetId string = firewallSubnet.id
output firewallManagementSubnetId string = firewallManagementSubnet.id
output gatewaySubnetId string = gatewaySubnet.id
