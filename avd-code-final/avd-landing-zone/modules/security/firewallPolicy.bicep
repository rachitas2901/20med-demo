@allowed([
  'Basic'
])
@description('Firewall Policy tier. Basic only. DNS proxy, TLS inspection, IDPS, web categories, and URL filtering are not configured.')
param sku string = 'Basic'
param policyName string
param location string
@description('Priority of the hub-owned platform rule collection. Spoke collections must use other priorities.')
param platformRulePriority int = 10000
param platformSourceCidrs array
param tags object = {}

var hasPlatformSources = length(platformSourceCidrs) > 0

resource policy 'Microsoft.Network/firewallPolicies@2024-05-01' = {
  name: policyName
  location: location
  tags: tags
  properties: {
    sku: {
      tier: sku
    }
    threatIntelMode: 'Alert'
  }
}

resource platformRules 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2024-05-01' = if (hasPlatformSources) {
  parent: policy
  name: 'rcg-platform'
  properties: {
    priority: platformRulePriority
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'NetworkRules_Platform'
        priority: 100
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'NetworkRule'
            name: 'Service Traffic'
            ipProtocols: [ 'TCP' ]
            sourceAddresses: platformSourceCidrs
            destinationAddresses: [ 'WindowsVirtualDesktop' ]
            destinationPorts: [ '443' ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'Agent Traffic'
            ipProtocols: [ 'TCP' ]
            sourceAddresses: platformSourceCidrs
            destinationAddresses: [ 'AzureMonitor' ]
            destinationPorts: [ '443' ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'Azure Marketplace'
            ipProtocols: [ 'TCP' ]
            sourceAddresses: platformSourceCidrs
            destinationAddresses: [ 'AzureFrontDoor.Frontend' ]
            destinationPorts: [ '443' ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'Windows activation'
            ipProtocols: [ 'TCP' ]
            sourceAddresses: platformSourceCidrs
            destinationAddresses: [ 'AzureCloud' ]
            destinationPorts: [ '1688' ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'FSLogix SMB'
            ipProtocols: [ 'TCP' ]
            sourceAddresses: platformSourceCidrs
            destinationAddresses: [ 'Storage' ]
            destinationPorts: [ '445' ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'STUN/TURN UDP'
            ipProtocols: [ 'UDP' ]
            sourceAddresses: platformSourceCidrs
            destinationAddresses: [ '20.202.0.0/16' ]
            destinationPorts: [ '3478' ]
          }
          {
            ruleType: 'NetworkRule'
            name: 'STUN/TURN TCP'
            ipProtocols: [ 'TCP' ]
            sourceAddresses: platformSourceCidrs
            destinationAddresses: [ '20.202.0.0/16' ]
            destinationPorts: [ '443' ]
          }
        ]
      }
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'ApplicationRules_Platform'
        priority: 200
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
            sourceAddresses: platformSourceCidrs
            targetFqdns: [
              '*.wvd.microsoft.com'
              '*.servicebus.windows.net'
              '*.prod.warm.ingest.monitor.core.windows.net'
            ]
          }
          {
            ruleType: 'ApplicationRule'
            name: 'avd-agent-and-entra'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            sourceAddresses: platformSourceCidrs
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
            sourceAddresses: platformSourceCidrs
            targetFqdns: [
              'oneocsp.microsoft.com'
              'www.microsoft.com'
              'crl.microsoft.com'
            ]
          }
          {
            ruleType: 'ApplicationRule'
            name: 'TelemetryService'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            sourceAddresses: platformSourceCidrs
            targetFqdns: [
              '*.events.data.microsoft.com'
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
            sourceAddresses: platformSourceCidrs
            targetFqdns: [
              '*.sfx.ms'
            ]
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
            sourceAddresses: platformSourceCidrs
            targetFqdns: [
              '*.digicert.com'
            ]
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
            sourceAddresses: platformSourceCidrs
            targetFqdns: [
              '*.azure-dns.com'
            ]
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
            sourceAddresses: platformSourceCidrs
            targetFqdns: [
              '*.azure-dns.net'
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
            sourceAddresses: platformSourceCidrs
            targetFqdns: [
              'www.msftconnecttest.com'
            ]
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
            sourceAddresses: platformSourceCidrs
            fqdnTags: [
              'WindowsUpdate'
            ]
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
            sourceAddresses: platformSourceCidrs
            fqdnTags: [
              'WindowsDiagnostics'
            ]
          }
        ]
      }
    ]
  }
}

output policyId string = policy.id
output policyName string = policy.name
