type fileShareType = {
  name: string
  quotaGb: int
  accessGroupObjectId: string
}

param storageAccountName string
param shares fileShareType[]
param location string
param provisionedIops int = 0
param provisionedThroughputMibps int = 0
param skuName string = 'Standard_LRS'
param accountKind string = 'StorageV2'
param shareAccessTier string = 'Hot'
param allowedSubnetIds array = []
param enablePrivateEndpoint bool = true
param privateEndpointSubnetId string = ''
param virtualNetworkId string
@description('Optional second link so hub clients can resolve the file private endpoint. Leave empty to link the spoke only.')
param hubVirtualNetworkId string = ''
param createPrivateDnsZone bool = true
param entraKerberosEnabled bool = false
param smbShareElevatedContributorPrincipalIds array = []
param tags object = {}

var smbContributorRoleId = '0c867c2a-1d8c-454a-a3db-ab2ea1bdc8bb'
var smbElevatedContributorRoleId = 'a7264617-510b-434b-a828-9731dc254ea7'
var virtualNetworkRules = [for subnetId in allowedSubnetIds: {
  id: subnetId
  action: 'Allow'
}]

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: skuName
  }
  kind: accountKind
  properties: union({
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    publicNetworkAccess: enablePrivateEndpoint ? 'Disabled' : 'Enabled'
    encryption: {
      requireInfrastructureEncryption: true
      keySource: 'Microsoft.Storage'
      services: {
        file: {
          enabled: true
          keyType: 'Account'
        }
      }
    }
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      virtualNetworkRules: virtualNetworkRules
    }
  }, entraKerberosEnabled ? {
    azureFilesIdentityBasedAuthentication: {
      directoryServiceOptions: 'AADKERB'
    }
  } : {})
}

resource share 'Microsoft.Storage/storageAccounts/fileServices/shares@2025-01-01' = [for item in shares: {
  name: '${storage.name}/default/${item.name}'
  properties: union({
    shareQuota: item.quotaGb
    enabledProtocols: 'SMB'
  }, provisionedIops > 0 ? {
    provisionedIops: provisionedIops
    provisionedBandwidthMibps: provisionedThroughputMibps
  } : {
    accessTier: shareAccessTier
  })
}]

resource dnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = if (enablePrivateEndpoint && createPrivateDnsZone) {
  name: 'privatelink.file.core.windows.net'
  location: 'global'
  tags: tags
}

resource dnsLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (enablePrivateEndpoint && createPrivateDnsZone) {
  parent: dnsZone
  name: 'link-${storageAccountName}'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetworkId
    }
  }
}

resource hubDnsLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = if (enablePrivateEndpoint && createPrivateDnsZone && !empty(hubVirtualNetworkId)) {
  parent: dnsZone
  name: 'link-hub-${storageAccountName}'
  location: 'global'
  tags: tags
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: hubVirtualNetworkId
    }
  }
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = if (enablePrivateEndpoint) {
  name: 'pe-${storageAccountName}-file'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'psc-file'
        properties: {
          privateLinkServiceId: storage.id
          groupIds: [
            'file'
          ]
        }
      }
    ]
  }
}

resource dnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = if (enablePrivateEndpoint && createPrivateDnsZone) {
  parent: privateEndpoint
  name: 'file-dns'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'file'
        properties: {
          privateDnsZoneId: dnsZone.id
        }
      }
    ]
  }
}

resource smbContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for (item, i) in shares: if (!empty(item.accessGroupObjectId)) {
  name: guid(share[i].id, item.accessGroupObjectId, smbContributorRoleId)
  scope: share[i]
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', smbContributorRoleId)
    principalId: item.accessGroupObjectId
    principalType: 'Group'
  }
}]

resource smbElevatedContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for principalId in smbShareElevatedContributorPrincipalIds: {
  name: guid(storage.id, principalId, smbElevatedContributorRoleId)
  scope: storage
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', smbElevatedContributorRoleId)
    principalId: principalId
    principalType: 'Group'
  }
}]

output storageAccountId string = storage.id
output storageAccountName string = storage.name
output shareName string = length(shares) > 0 ? shares[0].name : ''
output shareNames array = [for item in shares: item.name]
output fileShareUnc string = length(shares) > 0 ? '\\\\${storage.name}.file.core.windows.net\\${shares[0].name}' : ''
