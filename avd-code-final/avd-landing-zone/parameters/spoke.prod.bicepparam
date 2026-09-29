using '../main-spoke.bicep'

param location = 'centralindia'
param locationShort = 'cin'
param environment = 'prod'
param customerName = '20MED'
param resourcePrefix = '20med'
param hubResourceGroupName = 'rg-20med-network-hub-prod-cin'
param hubVnetName = 'vnet-20med-hub-prod-cin'
param firewallName = 'afw-20med-prod-cin'
param firewallPolicyName = 'afwp-20med-prod-cin'
param avdResourceGroupName = 'rg-20med-avd-prod-cin'
param deploymentPhase = 'avd'
param spokeVnetName = 'vnet-20med-avd-prod-cin'
param spokeAddressPrefix = '10.10.0.0/16'
param privateEndpointSubnetName = 'snet-privateendpoint'
param privateEndpointSubnetPrefix = '10.10.10.0/24'
param managementSubnetName = 'snet-management'
param managementSubnetPrefix = '10.10.11.0/24'
param bypassWindowsVirtualDesktopServiceTag = true
// No VPN gateway. Peering does not use gateway transit. Default route next hop is the hub firewall private IP.
param useHubGatewayTransit = false
// Priorities on the shared policy. Files = 20000. Workloads start at 30000 and step by 10.
param filesRulePriority = 20000
param workspaceRulePriorityBase = 30000

// Set enabled to true to add a workspace. That does not change the hub firewall or VPN gateway.
// abbrev must stay short. The computer name is abbrev-cin-nn and must be 15 characters or fewer.
// Lowering sessionHostCount stops managing the higher-numbered hosts. Delete those VMs explicitly. See docs/SCALING-AVD.md.
param avdWorkspaces = [
  {
    enabled: true
    key: 'de'
    abbrev: 'de'
    displayName: 'Data Engineering'
    workload: 'AVD'
    users: 10
    subnetName: 'snet-avd-de'
    subnetPrefix: '10.10.1.0/24'
    hostPoolName: 'HP-DataEngineering'
    workspaceName: 'WS-DataEngineering'
    applicationGroupName: 'DAG-DataEngineering'
    vmSize: 'Standard_D4s_v5'
    osDiskType: 'StandardSSD_LRS'
    osDiskSizeGb: 128
    sessionHostCount: 1
    maxSessionLimit: 4
    loadBalancerType: 'DepthFirst'
    fslogixShareName: 'de-fslogix'
    fslogixShareQuota: 100
    accessGroupObjectId: ''
    approvedApplicationFqdns: [
      'github.com'
      '*.github.com'
      '*.githubusercontent.com'
      '*.githubassets.com'
      '*.actions.githubusercontent.com'
      'ghcr.io'
      '*.fabric.microsoft.com'
      '*.powerbi.com'
      'app.powerbi.com'
      '*.analysis.windows.net'
      'portal.azure.com'
      '*.portal.azure.com'
      'management.azure.com'
      '*.management.azure.com'
      'learn.microsoft.com'
      'docs.microsoft.com'
      '*.docs.microsoft.com'
      '*.sqldbm.com'
      '*.office.com'
      '*.office365.com'
      '*.microsoftonline.com'
      '*.sharepoint.com'
      'login.microsoftonline.com'
      '*.login.microsoftonline.com'
    ]
  }
  {
    enabled: false
    key: 'prospecting'
    abbrev: 'pr'
    displayName: 'Prospecting'
    workload: 'AVD'
    users: 10
    subnetName: 'snet-avd-prospecting'
    subnetPrefix: '10.10.2.0/24'
    hostPoolName: 'HP-Prospecting'
    workspaceName: 'WS-Prospecting'
    applicationGroupName: 'DAG-Prospecting'
    vmSize: 'Standard_D4s_v5'
    osDiskType: 'StandardSSD_LRS'
    osDiskSizeGb: 128
    sessionHostCount: 1
    maxSessionLimit: 4
    loadBalancerType: 'DepthFirst'
    fslogixShareName: 'prospecting-fslogix'
    fslogixShareQuota: 100
    accessGroupObjectId: ''
    approvedApplicationFqdns: []
  }
  {
    enabled: false
    key: 'sales'
    abbrev: 'sa'
    displayName: 'Sales'
    workload: 'AVD'
    users: 10
    subnetName: 'snet-avd-sales'
    subnetPrefix: '10.10.3.0/24'
    hostPoolName: 'HP-Sales'
    workspaceName: 'WS-Sales'
    applicationGroupName: 'DAG-Sales'
    vmSize: 'Standard_D4s_v5'
    osDiskType: 'StandardSSD_LRS'
    osDiskSizeGb: 128
    sessionHostCount: 1
    maxSessionLimit: 4
    loadBalancerType: 'DepthFirst'
    fslogixShareName: 'sales-fslogix'
    fslogixShareQuota: 100
    accessGroupObjectId: ''
    approvedApplicationFqdns: []
  }
  {
    enabled: false
    key: 'reference'
    abbrev: 'rd'
    displayName: 'Reference Data'
    workload: 'AVD'
    users: 10
    subnetName: 'snet-avd-reference'
    subnetPrefix: '10.10.4.0/24'
    hostPoolName: 'HP-ReferenceData'
    workspaceName: 'WS-ReferenceData'
    applicationGroupName: 'DAG-ReferenceData'
    vmSize: 'Standard_D4s_v5'
    osDiskType: 'StandardSSD_LRS'
    osDiskSizeGb: 128
    sessionHostCount: 1
    maxSessionLimit: 4
    loadBalancerType: 'DepthFirst'
    fslogixShareName: 'reference-fslogix'
    fslogixShareQuota: 100
    accessGroupObjectId: ''
    approvedApplicationFqdns: []
  }
  {
    enabled: false
    key: 'finance'
    abbrev: 'fi'
    displayName: 'Finance'
    workload: 'AVD'
    users: 10
    subnetName: 'snet-avd-finance'
    subnetPrefix: '10.10.5.0/24'
    hostPoolName: 'HP-Finance'
    workspaceName: 'WS-Finance'
    applicationGroupName: 'DAG-Finance'
    vmSize: 'Standard_D4s_v5'
    osDiskType: 'StandardSSD_LRS'
    osDiskSizeGb: 128
    sessionHostCount: 1
    maxSessionLimit: 4
    loadBalancerType: 'DepthFirst'
    fslogixShareName: 'finance-fslogix'
    fslogixShareQuota: 100
    accessGroupObjectId: ''
    approvedApplicationFqdns: []
  }
]

param sessionHostImagePublisher = 'MicrosoftWindowsDesktop'
param sessionHostImageOffer = 'office-365'
param sessionHostImageSku = 'win11-24h2-avd-m365'

param storageAccountName = 'st20meddefslogixp'
param storageSkuName = 'Standard_LRS'
param storageAccountKind = 'StorageV2'
param storageShareAccessTier = 'Hot'

param logAnalyticsWorkspaceName = 'law-20med-avd-prod-cin'
param logAnalyticsRetentionDays = 30

param adminGroupObjectId = ''
param wvdServicePrincipalObjectId = ''

param enablePrivateEndpoints = true
param enableUat = false
param enableScalingPlan = true
param enableDeleteLock = false
param linkPrivateDnsToHub = false

param idleTimeoutMinutes = 30
param disconnectedTimeoutMinutes = 15

param alertEmail = ''
param localAdminUsername = 'avdadmin'
param localAdminPassword = readEnvironmentVariable('AVD_LOCAL_ADMIN_PASSWORD', '')
param avdDscModulesUrl = 'https://wvdportalstorageblob.blob.core.windows.net/galleryartifacts/Configuration_1.0.03362.1223.zip'

param resourceTags = {
  Environment: 'Prod'
  Workspace: 'DataEngineering'
  Workload: 'AVD'
  Owner: '20MED'
  Purpose: 'Data engineering workspace'
  ManagedBy: 'Bicep'
  Customer: '20MED'
}
