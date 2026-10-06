@allowed([
  'Basic'
])
param sku string = 'Basic'
param firewallName string
param location string
param firewallSubnetId string
param firewallManagementSubnetId string
param policyId string
param publicIpName string
param logAnalyticsWorkspaceId string = ''
param tags object = {}

resource publicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: publicIpName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
  tags: tags
}

resource managementPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: '${publicIpName}-mgmt'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
  tags: tags
}

resource firewall 'Microsoft.Network/azureFirewalls@2024-05-01' = {
  name: firewallName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: sku
    }
    firewallPolicy: {
      id: policyId
    }
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          subnet: {
            id: firewallSubnetId
          }
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
    managementIpConfiguration: {
      name: 'management'
      properties: {
        subnet: {
          id: firewallManagementSubnetId
        }
        publicIPAddress: {
          id: managementPublicIp.id
        }
      }
    }
  }
}

resource firewallDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: 'diag-afw-hub'
  scope: firewall
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output firewallId string = firewall.id
output privateIp string = firewall.properties.ipConfigurations[0].properties.privateIPAddress
output policyId string = policyId
