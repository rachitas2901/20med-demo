param prefix string
param location string
param locationShort string
param environment string
param diskCount int = 4
param storageAccountType string = 'Premium_LRS'
param diskSizeGb int = 128
param diskEncryptionSetId string = ''
param tags object = {}

resource disks 'Microsoft.Compute/disks@2024-03-02' = [for i in range(0, diskCount): {
  name: 'disk-${prefix}-${environment}-${locationShort}-${padLeft(string(i + 1), 2, '0')}'
  location: location
  tags: tags
  sku: {
    name: storageAccountType
  }
  properties: union({
    creationData: {
      createOption: 'Empty'
    }
    diskSizeGB: diskSizeGb
    publicNetworkAccess: 'Disabled'
    networkAccessPolicy: 'DenyAll'
  }, empty(diskEncryptionSetId) ? {} : {
    encryption: {
      diskEncryptionSetId: diskEncryptionSetId
    }
  })
}]

output diskIds array = [for i in range(0, diskCount): disks[i].id]
