targetScope = 'subscription'

@description('Shared hub only. Deploy this template on its own. Spoke deployments do not call it.')
param location string
param customerName string
param resourcePrefix string
param hubResourceGroupName string
param hubVnetName string
param hubAddressPrefix string
param firewallSubnetPrefix string
param firewallManagementSubnetPrefix string
param gatewaySubnetPrefix string
param firewallName string
param firewallPolicyName string
param firewallPublicIpName string

@allowed([
  'Basic'
])
param firewallSkuTier string
@description('Priority of rcg-platform. Spoke rule collections must not reuse this value.')
param platformRulePriority int = 10000
@description('Address ranges allowed to use platform rules. Covers the prod spoke without embedding workspace names.')
param platformSourceCidrs array
param logAnalyticsWorkspaceId string = ''
param enableDeleteLock bool
param resourceTags object

var hubTags = union(resourceTags, {
  Environment: 'Prod'
  Workspace: 'Shared'
  Workload: 'Network'
  Purpose: 'Shared hub network'
  Customer: customerName
  ManagedBy: 'Bicep'
  Owner: customerName
  Region: location
})

resource hubRg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: hubResourceGroupName
  location: location
  tags: hubTags
}

module hubLock 'modules/resourceGroupLock.bicep' = if (enableDeleteLock) {
  name: 'hub-rg-lock'
  scope: hubRg
  params: {
    lockName: '${hubResourceGroupName}-donotdelete'
  }
}

module hubNetwork 'modules/network/hubVnet.bicep' = {
  name: 'hub-network'
  scope: hubRg
  params: {
    vnetName: hubVnetName
    location: location
    addressPrefix: hubAddressPrefix
    firewallSubnetPrefix: firewallSubnetPrefix
    firewallManagementSubnetPrefix: firewallManagementSubnetPrefix
    gatewaySubnetPrefix: gatewaySubnetPrefix
    tags: hubTags
  }
}

module firewallPolicy 'modules/security/firewallPolicy.bicep' = {
  name: 'firewall-policy'
  scope: hubRg
  params: {
    sku: firewallSkuTier
    policyName: firewallPolicyName
    location: location
    platformRulePriority: platformRulePriority
    platformSourceCidrs: platformSourceCidrs
    tags: hubTags
  }
}

module firewall 'modules/security/firewall.bicep' = {
  name: 'firewall'
  scope: hubRg
  params: {
    sku: firewallSkuTier
    firewallName: firewallName
    location: location
    firewallSubnetId: hubNetwork.outputs.firewallSubnetId
    firewallManagementSubnetId: hubNetwork.outputs.firewallManagementSubnetId
    policyId: firewallPolicy.outputs.policyId
    publicIpName: firewallPublicIpName
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    tags: hubTags
  }
}

output hubResourceGroupName string = hubRg.name
output hubVnetId string = hubNetwork.outputs.vnetId
output firewallPrivateIp string = firewall.outputs.privateIp
output firewallPolicyId string = firewallPolicy.outputs.policyId
output resourcePrefix string = resourcePrefix
