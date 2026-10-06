param vnetName string
param prefix string
param location string
param locationShort string
param environment string
param addressSpace array

type spokeSubnets = {
  firewall: string
  firewallManagement: string
  privatelnk: string
}

param subnetPrefixes spokeSubnets
param avdNsgName string = ''
param customDnsServers array = []
param enableRdpPublicAccess bool = false
param rdpSourceAddressPrefixes array = [
  '0.0.0.0/0'
]
param privateEndpointSubnetName string = 'snet-privateendpoint'
param logAnalyticsWorkspaceId string = ''
param tags object = {}

var rdpSources = [for p in rdpSourceAddressPrefixes: (p == '*' || p == 'Internet') ? '0.0.0.0/0' : p]

resource avdNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: empty(avdNsgName) ? 'nsg-${prefix}-${environment}-${locationShort}' : avdNsgName
  location: location
  tags: tags
  properties: {
    securityRules: concat(enableRdpPublicAccess ? [
      {
        name: 'AllowRdpInbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefixes: rdpSources
          destinationAddressPrefix: '*'
        }
      }
    ] : [], [
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
    ])
  }
}

resource managementNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-mgmt-${prefix}-${environment}-${locationShort}'
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

resource privateLinkNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-privatelink-${prefix}-${environment}-${locationShort}'
  location: location
  tags: tags
  properties: {
    securityRules: []
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: union({
    addressSpace: {
      addressPrefixes: addressSpace
    }
  }, empty(customDnsServers) ? {} : {
    dhcpOptions: {
      dnsServers: customDnsServers
    }
  })
}

resource firewallSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: vnet
  name: 'AzureFirewallSubnet'
  properties: {
    addressPrefix: subnetPrefixes.firewall
  }
}

resource firewallManagementSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: vnet
  name: 'AzureFirewallManagementSubnet'
  properties: {
    addressPrefix: subnetPrefixes.firewallManagement
  }
}

resource privateLinkSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: vnet
  name: privateEndpointSubnetName
  properties: {
    addressPrefix: subnetPrefixes.privatelnk
    networkSecurityGroup: {
      id: privateLinkNsg.id
    }
    privateEndpointNetworkPolicies: 'Enabled'
  }
}

resource avdNsgDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: 'diag-nsg-avd'
  scope: avdNsg
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'NetworkSecurityGroupEvent'
        enabled: true
      }
      {
        category: 'NetworkSecurityGroupRuleCounter'
        enabled: true
      }
    ]
  }
}

output vnetId string = vnet.id
output vnetName string = vnet.name
output subnetFirewallId string = firewallSubnet.id
output subnetFirewallManagementId string = firewallManagementSubnet.id
output subnetPrivateLinkId string = privateLinkSubnet.id
output avdNsgId string = avdNsg.id
output managementNsgId string = managementNsg.id
