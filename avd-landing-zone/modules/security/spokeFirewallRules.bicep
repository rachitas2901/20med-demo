targetScope = 'resourceGroup'

param policyName string
param environment string
param storageAccountName string
param filesRulePriority int
param workspaceRulePriorityBase int
param sourceCidrs array

type workspaceRuleType = {
  key: string
  subnetPrefix: string
  fqdns: string[]
}

param workspaceRules workspaceRuleType[]

var storageFileFqdn = '${storageAccountName}.file.core.windows.net'

resource policy 'Microsoft.Network/firewallPolicies@2024-05-01' existing = {
  name: policyName
}

resource filesRules 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2024-05-01' = if (length(sourceCidrs) > 0) {
  parent: policy
  name: 'rcg-avd-files-${environment}'
  properties: {
    priority: filesRulePriority
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: 'files-allow'
        priority: 100
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: 'storage-account-https'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            sourceAddresses: sourceCidrs
            targetFqdns: [
              storageFileFqdn
            ]
          }
        ]
      }
    ]
  }
}

resource workspaceRuleGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2024-05-01' = [for (rule, i) in workspaceRules: if (length(rule.fqdns) > 0) {
  parent: policy
  name: 'rcg-avd-${rule.key}-${environment}'
  properties: {
    priority: workspaceRulePriorityBase + (i * 10)
    ruleCollections: [
      {
        ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
        name: '${rule.key}-allow'
        priority: 100
        action: {
          type: 'Allow'
        }
        rules: [
          {
            ruleType: 'ApplicationRule'
            name: '${rule.key}-saas'
            protocols: [
              {
                protocolType: 'Https'
                port: 443
              }
            ]
            sourceAddresses: [
              rule.subnetPrefix
            ]
            targetFqdns: rule.fqdns
          }
        ]
      }
    ]
  }
}]
