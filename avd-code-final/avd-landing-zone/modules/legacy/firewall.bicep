param prefix string
param location string
param locationShort string
param environment string
param firewallSubnetId string
param firewallManagementSubnetId string
param avdSubnetCidrs array
param allowedEgressFqdns array = []
param sku string = 'Basic'
param firewallName string = ''
param policyName string = ''
param publicIpName string = ''
param approvedApplicationFqdns array = []
param storageAccountName string
param logAnalyticsWorkspaceId string = ''
param zones array = []
param publicIpZones array = []
param tags object = {}

var resolvedFirewallName = empty(firewallName) ? 'afw-${prefix}-${environment}-${locationShort}' : firewallName
var resolvedPolicyName = empty(policyName) ? 'afwp-${prefix}-${environment}-${locationShort}' : policyName
var resolvedPublicIpName = empty(publicIpName) ? 'pip-afw-${prefix}-${environment}-${locationShort}' : publicIpName

var defaultControlPlaneFqdns = [
  '*.wvd.microsoft.com'
  '*.servicebus.windows.net'
  '*.prod.warm.ingest.monitor.core.windows.net'
]
var controlPlaneFqdns = concat(defaultControlPlaneFqdns, allowedEgressFqdns)
var storageFileFqdn = '${storageAccountName}.file.core.windows.net'

resource publicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: resolvedPublicIpName
  location: location
  zones: empty(publicIpZones) ? null : publicIpZones
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
  name: '${resolvedPublicIpName}-mgmt'
  location: location
  zones: empty(publicIpZones) ? null : publicIpZones
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
  tags: tags
}

resource policy 'Microsoft.Network/firewallPolicies@2024-05-01' = {
  name: resolvedPolicyName
  location: location
  tags: tags
  properties: {
    sku: {
      tier: sku
    }
    threatIntelMode: sku == 'Basic' ? 'Alert' : 'Deny'
  }
}

resource egressRules 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2024-05-01' = {
  parent: policy
  name: 'rcg-egress'
  properties: {
    priority: 500
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'avd-required-fqdns'
        priority: 500
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'avd-control-plane'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            sourceAddresses: avdSubnetCidrs
            targetFqdns: controlPlaneFqdns
          }
        ]
      }
    ]
  }
}

resource avdCoreRules 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2024-05-01' = {
  parent: policy
  name: 'AVD-Core'
  properties: {
    priority: 10000
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'NetworkRules_AVD-Core'
        priority: 11000
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'Service Traffic'
            ipProtocols: [ 'TCP' ]
            sourceAddresses: avdSubnetCidrs
            destinationAddresses: [ 'WindowsVirtualDesktop' ]
            destinationPorts: [ '443' ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'Agent Traffic (1)'
            ipProtocols: [ 'TCP' ]
            sourceAddresses: avdSubnetCidrs
            destinationAddresses: [ 'AzureMonitor' ]
            destinationPorts: [ '443' ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'Azure Marketplace'
            ipProtocols: [ 'TCP' ]
            sourceAddresses: avdSubnetCidrs
            destinationAddresses: [ 'AzureFrontDoor.Frontend' ]
            destinationPorts: [ '443' ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'Windows activation'
            ipProtocols: [ 'TCP' ]
            sourceAddresses: avdSubnetCidrs
            destinationAddresses: [ 'AzureCloud' ]
            destinationPorts: [ '1688' ]
          }
        ]
      }
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'ApplicationRules_AVD-Core'
        priority: 12000
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'avd-agent-and-entra'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            sourceAddresses: avdSubnetCidrs
            targetFqdns: [
              'gcs.prod.monitoring.core.windows.net'
              'mrsglobalsteus2prod.blob.core.windows.net'
              'wvdportalstorageblob.blob.core.windows.net'
              'login.microsoftonline.com'
              'login.windows.net'
              'enterpriseregistration.windows.net'
              'device.login.microsoftonline.com'
              'pas.windows.net'
              '*.msauth.net'
              '*.msftauth.net'
            ]
          }
          {
            ruleType: 'ApplicationRule'
            name: 'certificate-crl'
            protocols: [
              {
                protocolType: 'Http'
                port: 80
              }
            ]
            sourceAddresses: avdSubnetCidrs
            targetFqdns: [
              'oneocsp.microsoft.com'
              'www.microsoft.com'
              'crl.microsoft.com'
            ]
          }
        ]
      }
    ]
  }
}

resource infrastructureRules 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2024-05-01' = {
  parent: policy
  name: 'Infrastructure'
  properties: {
    priority: 15000
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'NetworkRules_FSLogix'
        priority: 15100
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'FSLogix SMB'
            ipProtocols: [ 'TCP' ]
            sourceAddresses: avdSubnetCidrs
            destinationAddresses: [ 'Storage' ]
            destinationPorts: [ '445' ]
          }
        ]
      }
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'ApplicationRules_AzureFiles'
        priority: 15200
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'AzureFilesManagement'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            sourceAddresses: avdSubnetCidrs
            targetFqdns: [ storageFileFqdn ]
          }
        ]
      }
    ]
  }
}

resource avdOptionalRules 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2024-05-01' = {
  parent: policy
  name: 'AVD-Optional'
  properties: {
    priority: 20000
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'NetworkRules_AVD-Optional'
        priority: 21000
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'STUN/TURN UDP'
            ipProtocols: [ 'UDP' ]
            sourceAddresses: avdSubnetCidrs
            destinationAddresses: [ '20.202.0.0/16' ]
            destinationPorts: [ '3478' ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'STUN/TURN TCP'
            ipProtocols: [ 'TCP' ]
            sourceAddresses: avdSubnetCidrs
            destinationAddresses: [ '20.202.0.0/16' ]
            destinationPorts: [ '443' ]
          }
        ]
      }
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'ApplicationRules_AVD-Optional'
        priority: 22000
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'TelemetryService'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            sourceAddresses: avdSubnetCidrs
            targetFqdns: [ '*.events.data.microsoft.com' ]
          }
          {
            ruleType: 'ApplicationRule'
            name: 'WindowsUpdate'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            sourceAddresses: avdSubnetCidrs
            fqdnTags: [
              'WindowsUpdate'
            ]
          }
          {
            ruleType: 'ApplicationRule'
            name: 'UpdatesForOneDrive'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            sourceAddresses: avdSubnetCidrs
            targetFqdns: [ '*.sfx.ms' ]
          }
          {
            ruleType: 'ApplicationRule'
            name: 'DigitcertCRL'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            sourceAddresses: avdSubnetCidrs
            targetFqdns: [ '*.digicert.com' ]
          }
          {
            ruleType: 'ApplicationRule'
            name: 'AzureDNSresolution1'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            sourceAddresses: avdSubnetCidrs
            targetFqdns: [ '*.azure-dns.com' ]
          }
          {
            ruleType: 'ApplicationRule'
            name: 'AzureDNSresolution2'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            sourceAddresses: avdSubnetCidrs
            targetFqdns: [ '*.azure-dns.net' ]
          }
          {
            ruleType: 'ApplicationRule'
            name: 'WindowsDiagnostics'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            sourceAddresses: avdSubnetCidrs
            fqdnTags: [
              'WindowsDiagnostics'
            ]
          }
          {
            ruleType: 'ApplicationRule'
            name: 'connectivity-check'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            sourceAddresses: avdSubnetCidrs
            targetFqdns: [
              'www.msftconnecttest.com'
            ]
          }
        ]
      }
    ]
  }
}

resource approvedRules 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2024-05-01' = if (!empty(approvedApplicationFqdns)) {
  parent: policy
  name: 'rcg-approved'
  properties: {
    priority: 400
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'approved-saas'
        priority: 400
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'approved-destinations'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            sourceAddresses: avdSubnetCidrs
            targetFqdns: approvedApplicationFqdns
          }
        ]
      }
    ]
  }
}

resource firewall 'Microsoft.Network/azureFirewalls@2024-05-01' = {
  name: resolvedFirewallName
  location: location
  zones: empty(zones) ? null : zones
  tags: tags
  dependsOn: [
    egressRules
    avdCoreRules
    infrastructureRules
    avdOptionalRules
    approvedRules
  ]
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: sku
    }
    firewallPolicy: {
      id: policy.id
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
  name: 'diag-afw-law'
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
output policyId string = policy.id
output policyName string = policy.name
output ruleCollectionGroups array = concat([
  egressRules.name
  avdCoreRules.name
  infrastructureRules.name
  avdOptionalRules.name
], empty(approvedApplicationFqdns) ? [] : [
  approvedRules!.name
])
