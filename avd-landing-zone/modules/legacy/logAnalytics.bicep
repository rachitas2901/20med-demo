param prefix string
param location string
param locationShort string
param environment string
param retentionInDays int = 30
param workspaceName string = ''
param tags object = {}

var resolvedName = empty(workspaceName) ? 'law-${prefix}-${environment}-${locationShort}' : workspaceName

resource workspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' = {
  name: resolvedName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionInDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    #disable-next-line BCP037
    disableLocalAuth: true
  }
}

output workspaceId string = workspace.id
output workspaceGuid string = workspace.properties.customerId
output workspaceName string = workspace.name
