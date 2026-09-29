type hostPoolType = {
  name: string
  abbrev: string
  friendlyName: string
  users: int
  workload: string
  maxSessionsLimit: int
  sessionHostCount: int
  sessionHostIndices: int[]
  hostPoolResourceName: string
  workspaceResourceName: string
  applicationGroupResourceName: string
  vmSize: string
  osDiskType: string
  osDiskSizeGb: int
  fslogixShareName: string
  fslogixShareQuota: int
  accessGroupObjectId: string
}

param hostPools hostPoolType[]
param prefix string
param location string
param locationShort string
param environment string
param subnetId string
param sourceImageId string = ''
param imagePublisher string = 'MicrosoftWindowsDesktop'
param imageOffer string = 'office-365'
param imageSku string = 'win11-24h2-avd-m365'
param localAdminUsername string

@secure()
param localAdminPassword string
param encryptionAtHostEnabled bool = false
param avdDscModulesUrl string
param registrationTokenExpiration string
param enableRdpPublicIp bool = false
param rdpPublicIpHostKey string = ''
param enableFslogix bool = true
param fslogixStorageAccountName string = ''
param logAnalyticsWorkspaceId string = ''
param enableScalingPlan bool = true
param enableUat bool = false
param idleTimeoutMinutes int = 30
param disconnectedTimeoutMinutes int = 15
param wvdServicePrincipalObjectId string = ''
param tags object = {}

var powerOnOffRoleId = '40c5ff49-9181-41f8-ae61-143b0e78555e'
var vmUserLoginRoleId = 'fb879df8-f326-4884-b1cf-06f3ad86be52'

resource vmUserLogin 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for pool in hostPools: if (!empty(pool.accessGroupObjectId)) {
  name: guid(resourceGroup().id, pool.accessGroupObjectId, vmUserLoginRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', vmUserLoginRoleId)
    principalId: pool.accessGroupObjectId
    principalType: 'Group'
  }
}]

resource wvdPowerOn 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(wvdServicePrincipalObjectId)) {
  name: guid(resourceGroup().id, wvdServicePrincipalObjectId, powerOnOffRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', powerOnOffRoleId)
    principalId: wvdServicePrincipalObjectId
    principalType: 'ServicePrincipal'
  }
}

var rdpEnabled = enableRdpPublicIp && !empty(rdpPublicIpHostKey)
var rdpSeparator = lastIndexOf(rdpPublicIpHostKey, '-')
var rdpPoolName = rdpSeparator > 0 ? substring(rdpPublicIpHostKey, 0, rdpSeparator) : ''
var rdpIndex = rdpSeparator > 0 ? int(substring(rdpPublicIpHostKey, rdpSeparator + 1)) : -1

resource rdpPublicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = if (rdpEnabled) {
  name: 'pip-${prefix}-rdp'
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

module pools 'avdPool.bicep' = [for pool in hostPools: {
  name: 'avd-${pool.name}'
  params: {
    pool: pool
    prefix: prefix
    location: location
    locationShort: locationShort
    environment: environment
    subnetId: subnetId
    sourceImageId: sourceImageId
    imagePublisher: imagePublisher
    imageOffer: imageOffer
    imageSku: imageSku
    localAdminUsername: localAdminUsername
    localAdminPassword: localAdminPassword
    encryptionAtHostEnabled: encryptionAtHostEnabled
    avdDscModulesUrl: avdDscModulesUrl
    registrationTokenExpiration: registrationTokenExpiration
    rdpPublicIpId: rdpEnabled && pool.name == rdpPoolName ? rdpPublicIp!.id : ''
    rdpHostIndex: pool.name == rdpPoolName ? rdpIndex : -1
    enableFslogix: enableFslogix
    fslogixStorageAccountName: fslogixStorageAccountName
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    enableScalingPlan: enableScalingPlan
    enableUat: enableUat
    idleTimeoutMinutes: idleTimeoutMinutes
    disconnectedTimeoutMinutes: disconnectedTimeoutMinutes
    tags: tags
  }
}]

output workspaceIds array = [for i in range(0, length(hostPools)): {
  name: hostPools[i].name
  id: pools[i].outputs.workspaceId
}]
output hostPoolIds array = [for i in range(0, length(hostPools)): {
  name: hostPools[i].name
  id: pools[i].outputs.hostPoolId
}]
output rdpPublicIpAddress string = rdpEnabled ? rdpPublicIp!.properties.ipAddress : ''
output rdpPublicIpHostKey string = rdpEnabled ? rdpPublicIpHostKey : ''
output hostPoolId string = length(hostPools) > 0 ? pools[0].outputs.hostPoolId : ''
output hostPoolName string = length(hostPools) > 0 ? pools[0].outputs.hostPoolName : ''
output workspaceId string = length(hostPools) > 0 ? pools[0].outputs.workspaceId : ''
output applicationGroupId string = length(hostPools) > 0 ? pools[0].outputs.applicationGroupId : ''
output sessionHostVmIds array = length(hostPools) > 0 ? pools[0].outputs.sessionHostVmIds : []
