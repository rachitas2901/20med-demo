param vnetName string
param prefix string
param location string
param locationShort string
param environment string
param addressSpace array

type hubSubnets = {
  gateway: string
  nat: string
  firewall: string
}

param subnetPrefixes hubSubnets
param enableFirewallSubnet bool = false
param tags object = {}

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-hub-${prefix}-${environment}-${locationShort}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowVnetInbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          destinationAddressPrefix: 'VirtualNetwork'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourcePortRange: '*'
          destinationPortRange: '*'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: addressSpace
    }
  }
}

resource gatewaySubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: vnet
  name: 'GatewaySubnet'
  properties: {
    addressPrefix: subnetPrefixes.gateway
  }
}

resource natSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: vnet
  name: 'snet-hub-nat'
  properties: {
    addressPrefix: subnetPrefixes.nat
    networkSecurityGroup: {
      id: nsg.id
    }
  }
}

resource firewallSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = if (enableFirewallSubnet) {
  parent: vnet
  name: 'AzureFirewallSubnet'
  properties: {
    addressPrefix: subnetPrefixes.firewall
  }
}

output vnetId string = vnet.id
output vnetName string = vnet.name
output subnetGatewayId string = gatewaySubnet.id
output subnetNatId string = natSubnet.id
output subnetFirewallId string = enableFirewallSubnet ? firewallSubnet!.id : ''
