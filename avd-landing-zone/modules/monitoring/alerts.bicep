param actionGroupName string
param alertEmail string
param firewallResourceId string = ''
param tags object = {}

resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = if (!empty(alertEmail)) {
  name: actionGroupName
  location: 'global'
  tags: tags
  properties: {
    groupShortName: 'avdops'
    enabled: true
    emailReceivers: [
      {
        name: 'ops'
        emailAddress: alertEmail
        useCommonAlertSchema: true
      }
    ]
  }
}

resource firewallAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = if (!empty(alertEmail) && !empty(firewallResourceId)) {
  name: 'firewall-unhealthy'
  location: 'global'
  tags: tags
  properties: {
    description: 'Azure Firewall health dropped below 90. A healthy firewall reports 100.'
    severity: 1
    enabled: true
    scopes: [
      firewallResourceId
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    targetResourceType: 'Microsoft.Network/azureFirewalls'
    targetResourceRegion: resourceGroup().location
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'health'
          metricName: 'FirewallHealth'
          metricNamespace: 'Microsoft.Network/azureFirewalls'
          operator: 'LessThan'
          threshold: 90
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
      }
    ]
  }
}
