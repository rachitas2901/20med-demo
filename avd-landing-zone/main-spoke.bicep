targetScope = 'subscription'

@description('One AVD spoke. References the hub with existing. Does not create or modify the firewall, VPN gateway, hub subnets, or hub public IPs.')
param location string
param locationShort string
param environment string
param customerName string
param resourcePrefix string
param hubResourceGroupName string
param hubVnetName string
param firewallName string
param firewallPolicyName string
param avdResourceGroupName string

@allowed([
  'landing_zone'
  'avd'
])
param deploymentPhase string

param spokeVnetName string
param spokeAddressPrefix string
param privateEndpointSubnetName string
param privateEndpointSubnetPrefix string
param managementSubnetName string
param managementSubnetPrefix string
param bypassWindowsVirtualDesktopServiceTag bool = true

@description('Must match the hub. True uses the existing hub VPN gateway for this spoke. This template does not create that gateway.')
param useHubGatewayTransit bool
@description('Priority for this spoke file-share rule group. Must be unique on the shared policy.')
param filesRulePriority int
@description('Base priority for this spoke workspace rule groups. Must not overlap another spoke or rcg-platform.')
param workspaceRulePriorityBase int

type avdWorkspaceType = {
  enabled: bool
  key: string
  abbrev: string
  displayName: string
  workload: string
  users: int
  subnetName: string
  subnetPrefix: string
  hostPoolName: string
  workspaceName: string
  applicationGroupName: string
  vmSize: string
  osDiskType: string
  osDiskSizeGb: int
  sessionHostCount: int
  maxSessionLimit: int
  loadBalancerType: string
  fslogixShareName: string
  fslogixShareQuota: int
  accessGroupObjectId: string
  approvedApplicationFqdns: string[]
}

param avdWorkspaces avdWorkspaceType[]
param sessionHostImagePublisher string
param sessionHostImageOffer string
param sessionHostImageSku string
param storageAccountName string
param storageSkuName string
param storageAccountKind string
param storageShareAccessTier string
param logAnalyticsWorkspaceName string
param logAnalyticsRetentionDays int
param adminGroupObjectId string
param wvdServicePrincipalObjectId string
param enablePrivateEndpoints bool
param enableUat bool
param enableScalingPlan bool
param enableDeleteLock bool
param linkPrivateDnsToHub bool = false
param idleTimeoutMinutes int
param disconnectedTimeoutMinutes int
param alertEmail string
param localAdminUsername string

@secure()
param localAdminPassword string
param avdDscModulesUrl string
param registrationTokenExpiration string = dateTimeAdd(utcNow(), 'P27D')
param resourceTags object

var deployAvd = deploymentPhase == 'avd'
var enabledWorkspaces = filter(avdWorkspaces, ws => ws.enabled)
var enabledSubnetCidrs = map(enabledWorkspaces, ws => ws.subnetPrefix)
var workspaceFirewallRules = map(filter(enabledWorkspaces, ws => length(ws.approvedApplicationFqdns) > 0), ws => {
  key: ws.key
  subnetPrefix: ws.subnetPrefix
  fqdns: ws.approvedApplicationFqdns
})
var fslogixShares = map(enabledWorkspaces, ws => {
  name: ws.fslogixShareName
  quotaGb: ws.fslogixShareQuota
  accessGroupObjectId: ws.accessGroupObjectId
})
var accessGroupObjectIds = map(filter(enabledWorkspaces, ws => !empty(ws.accessGroupObjectId)), ws => ws.accessGroupObjectId)
var spokeTags = union(resourceTags, {
  Workload: 'AVD'
  Customer: customerName
  ManagedBy: 'Bicep'
  Owner: customerName
  Region: location
})

resource hubRg 'Microsoft.Resources/resourceGroups@2024-03-01' existing = {
  name: hubResourceGroupName
}

resource hubVnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: hubVnetName
  scope: hubRg
}

// ipConfigurations[0] is the AzureFirewallSubnet data-plane NIC. The management NIC is managementIpConfiguration and is not a valid next hop.
resource hubFirewall 'Microsoft.Network/azureFirewalls@2024-05-01' existing = {
  name: firewallName
  scope: hubRg
}

resource hubFirewallPolicy 'Microsoft.Network/firewallPolicies@2024-05-01' existing = {
  name: firewallPolicyName
  scope: hubRg
}

resource avdRg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: avdResourceGroupName
  location: location
  tags: spokeTags
}

module avdLock 'modules/resourceGroupLock.bicep' = if (enableDeleteLock) {
  name: 'avd-rg-lock'
  scope: avdRg
  params: {
    lockName: '${avdResourceGroupName}-donotdelete'
  }
}

module logAnalytics 'modules/monitoring/logAnalytics.bicep' = {
  name: 'log-analytics'
  scope: avdRg
  params: {
    prefix: resourcePrefix
    location: location
    locationShort: locationShort
    environment: environment
    retentionInDays: logAnalyticsRetentionDays
    workspaceName: logAnalyticsWorkspaceName
    tags: spokeTags
  }
}

module spokeNetwork 'modules/network/spokeVnet.bicep' = {
  name: 'spoke-network'
  scope: avdRg
  params: {
    vnetName: spokeVnetName
    location: location
    addressPrefix: spokeAddressPrefix
    tags: spokeTags
  }
}

module privateEndpointNsg 'modules/network/nsg.bicep' = {
  name: 'nsg-privateendpoint'
  scope: avdRg
  params: {
    profile: 'privateendpoint'
    nsgName: 'nsg-privateendpoint-${environment}'
    location: location
    tags: spokeTags
  }
}

module managementNsg 'modules/network/nsg.bicep' = {
  name: 'nsg-management'
  scope: avdRg
  params: {
    profile: 'management'
    nsgName: 'nsg-management-${environment}'
    location: location
    enableDiagnostics: true
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    tags: spokeTags
  }
}

module workloadNsg 'modules/network/nsg.bicep' = [for ws in enabledWorkspaces: {
  name: 'nsg-${ws.key}'
  scope: avdRg
  params: {
    profile: 'avd'
    nsgName: 'nsg-avd-${ws.key}-${environment}'
    location: location
    enableDiagnostics: true
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    tags: union(spokeTags, { Workspace: ws.displayName })
  }
}]

module privateEndpointSubnet 'modules/network/subnet.bicep' = {
  name: 'snet-privateendpoint'
  scope: avdRg
  params: {
    vnetName: spokeNetwork.outputs.vnetName
    subnetName: privateEndpointSubnetName
    addressPrefix: privateEndpointSubnetPrefix
    nsgId: privateEndpointNsg.outputs.nsgId
  }
}

module spokeFirewallRules 'modules/security/spokeFirewallRules.bicep' = {
  name: 'spoke-firewall-rules'
  scope: hubRg
  params: {
    policyName: firewallPolicyName
    environment: environment
    storageAccountName: storageAccountName
    filesRulePriority: filesRulePriority
    workspaceRulePriorityBase: workspaceRulePriorityBase
    sourceCidrs: enabledSubnetCidrs
    workspaceRules: workspaceFirewallRules
  }
}

module hubToSpoke 'modules/network/peering.bicep' = {
  name: 'peer-hub-to-spoke'
  scope: hubRg
  params: {
    localVnetName: hubVnetName
    remoteVnetId: spokeNetwork.outputs.vnetId
    peeringName: 'peer-to-${spokeVnetName}'
    allowGatewayTransit: useHubGatewayTransit
    useRemoteGateways: false
  }
}

module spokeToHub 'modules/network/peering.bicep' = {
  name: 'peer-spoke-to-hub'
  scope: avdRg
  dependsOn: [
    hubToSpoke
  ]
  params: {
    localVnetName: spokeNetwork.outputs.vnetName
    remoteVnetId: hubVnet.id
    peeringName: 'peer-to-${hubVnetName}'
    allowGatewayTransit: false
    useRemoteGateways: useHubGatewayTransit
  }
}

module managementRoute 'modules/network/routeTable.bicep' = {
  name: 'rt-management'
  scope: avdRg
  params: {
    routeTableName: 'rt-management-${environment}'
    location: location
    firewallPrivateIp: hubFirewall.properties.ipConfigurations[0].properties.privateIPAddress
    bypassWindowsVirtualDesktopServiceTag: bypassWindowsVirtualDesktopServiceTag
    tags: spokeTags
  }
}

module workloadRoute 'modules/network/routeTable.bicep' = [for ws in enabledWorkspaces: {
  name: 'rt-${ws.key}'
  scope: avdRg
  params: {
    routeTableName: 'rt-avd-${ws.key}-${environment}'
    location: location
    firewallPrivateIp: hubFirewall.properties.ipConfigurations[0].properties.privateIPAddress
    bypassWindowsVirtualDesktopServiceTag: bypassWindowsVirtualDesktopServiceTag
    tags: union(spokeTags, { Workspace: ws.displayName })
  }
}]

module managementSubnet 'modules/network/subnet.bicep' = {
  name: 'snet-management'
  scope: avdRg
  params: {
    vnetName: spokeNetwork.outputs.vnetName
    subnetName: managementSubnetName
    addressPrefix: managementSubnetPrefix
    nsgId: managementNsg.outputs.nsgId
    routeTableId: managementRoute.outputs.routeTableId
  }
}

module workloadSubnet 'modules/network/subnet.bicep' = [for (ws, i) in enabledWorkspaces: {
  name: 'snet-${ws.key}'
  scope: avdRg
  params: {
    vnetName: spokeNetwork.outputs.vnetName
    subnetName: ws.subnetName
    addressPrefix: ws.subnetPrefix
    nsgId: workloadNsg[i].outputs.nsgId
    routeTableId: workloadRoute[i].outputs.routeTableId
    enableStorageServiceEndpoint: true
  }
}]

module storage 'modules/storage/fslogix.bicep' = {
  name: 'fslogix-storage'
  scope: avdRg
  params: {
    storageAccountName: storageAccountName
    shares: fslogixShares
    location: location
    skuName: storageSkuName
    accountKind: storageAccountKind
    shareAccessTier: storageShareAccessTier
    enablePrivateEndpoint: enablePrivateEndpoints
    allowedSubnetIds: [for i in range(0, length(enabledWorkspaces)): workloadSubnet[i].outputs.subnetId]
    privateEndpointSubnetId: privateEndpointSubnet.outputs.subnetId
    virtualNetworkId: spokeNetwork.outputs.vnetId
    hubVirtualNetworkId: linkPrivateDnsToHub ? hubVnet.id : ''
    createPrivateDnsZone: enablePrivateEndpoints
    entraKerberosEnabled: true
    smbShareElevatedContributorPrincipalIds: empty(adminGroupObjectId) ? [] : [
      adminGroupObjectId
    ]
    tags: spokeTags
  }
}

module sessionHosts 'modules/avd/avdPool.bicep' = [for (ws, i) in enabledWorkspaces: if (deployAvd) {
  name: 'avd-${ws.key}'
  scope: avdRg
  dependsOn: [
    spokeToHub
  ]
  params: {
    pool: ws
    prefix: resourcePrefix
    location: location
    locationShort: locationShort
    environment: environment
    subnetId: workloadSubnet[i].outputs.subnetId
    imagePublisher: sessionHostImagePublisher
    imageOffer: sessionHostImageOffer
    imageSku: sessionHostImageSku
    localAdminUsername: localAdminUsername
    localAdminPassword: localAdminPassword
    avdDscModulesUrl: avdDscModulesUrl
    registrationTokenExpiration: registrationTokenExpiration
    enableFslogix: true
    fslogixStorageAccountName: storage.outputs.storageAccountName
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    enableScalingPlan: enableScalingPlan
    enableUat: enableUat
    idleTimeoutMinutes: idleTimeoutMinutes
    disconnectedTimeoutMinutes: disconnectedTimeoutMinutes
    tags: spokeTags
  }
}]

module access 'modules/avd/access.bicep' = if (deployAvd) {
  name: 'avd-access'
  scope: avdRg
  params: {
    accessGroupObjectIds: accessGroupObjectIds
    wvdServicePrincipalObjectId: wvdServicePrincipalObjectId
  }
}

module alerts 'modules/monitoring/alerts.bicep' = if (!empty(alertEmail)) {
  name: 'alerts'
  scope: avdRg
  params: {
    actionGroupName: 'ag-${resourcePrefix}-avd-${environment}'
    alertEmail: alertEmail
    firewallResourceId: hubFirewall.id
    tags: spokeTags
  }
}

output avdResourceGroupName string = avdRg.name
output hubVnetId string = hubVnet.id
output spokeVnetId string = spokeNetwork.outputs.vnetId
output firewallPrivateIp string = hubFirewall.properties.ipConfigurations[0].properties.privateIPAddress
output firewallPolicyId string = hubFirewallPolicy.id
output enabledWorkspaceKeys array = map(enabledWorkspaces, ws => ws.key)
output disabledWorkspaceKeys array = map(filter(avdWorkspaces, ws => !ws.enabled), ws => ws.key)
output fslogixShareNames array = storage.outputs.shareNames
output storageAccountId string = storage.outputs.storageAccountId
output logAnalyticsWorkspaceId string = logAnalytics.outputs.workspaceId
output spokePeeringUsesRemoteGateways bool = useHubGatewayTransit
output managementAccess string = 'Management subnet only. No jump host and no Bastion.'
