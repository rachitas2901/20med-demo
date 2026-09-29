@description('avd denies unsolicited inbound. management allows virtual network inbound. privateendpoint keeps Azure default rules so private endpoint traffic is not denied.')
@allowed([
  'avd'
  'management'
  'privateendpoint'
])
param profile string
param nsgName string
param location string
param logAnalyticsWorkspaceId string = ''
param enableDiagnostics bool = false
param tags object = {}

var denyAllInbound = {
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

var allowVnetInbound = {
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

var securityRules = profile == 'avd' ? [
  denyAllInbound
] : profile == 'management' ? [
  allowVnetInbound
  denyAllInbound
] : []

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    securityRules: securityRules
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (enableDiagnostics && !empty(logAnalyticsWorkspaceId)) {
  name: 'diag-${nsgName}'
  scope: nsg
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

output nsgId string = nsg.id
