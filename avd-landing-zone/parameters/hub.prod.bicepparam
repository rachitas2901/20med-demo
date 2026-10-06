using '../main-hub.bicep'

param location = 'centralindia'
param customerName = '20MED'
param resourcePrefix = '20med'
param hubResourceGroupName = 'rg-20med-network-hub-prod-cin'
param hubVnetName = 'vnet-20med-hub-prod-cin'
param hubAddressPrefix = '10.20.0.0/16'
param firewallSubnetPrefix = '10.20.1.0/26'
param firewallManagementSubnetPrefix = '10.20.1.64/26'
param gatewaySubnetPrefix = '10.20.2.0/26'

param firewallName = 'afw-20med-prod-cin'
param firewallPolicyName = 'afwp-20med-prod-cin'
param firewallPublicIpName = 'pip-afw-20med-prod-cin'
param firewallSkuTier = 'Basic'
// 10000 is reserved for rcg-platform. Spoke files use 20xxx. Spoke workloads use 30xxx.
param platformRulePriority = 10000
param platformSourceCidrs = [
  '10.10.0.0/16'
]

param logAnalyticsWorkspaceId = ''
param enableDeleteLock = false

param resourceTags = {
  Environment: 'Prod'
  Workspace: 'Shared'
  Workload: 'Network'
  Owner: '20MED'
  Purpose: 'Shared hub network'
  ManagedBy: 'Bicep'
  Customer: '20MED'
}
