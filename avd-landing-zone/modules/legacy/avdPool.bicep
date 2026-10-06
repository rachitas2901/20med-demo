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

param pool hostPoolType
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
param publicNetworkAccessEnabled bool = true
param avdDscModulesUrl string
param registrationTokenExpiration string
param rdpPublicIpId string = ''
param rdpHostIndex int = -1
param enableFslogix bool = true
param fslogixStorageAccountName string = ''
param logAnalyticsWorkspaceId string = ''
param enableScalingPlan bool = true
param enableUat bool = false
param idleTimeoutMinutes int = 30
param disconnectedTimeoutMinutes int = 15
param tags object = {}

var poolTags = union(tags, { Workspace: pool.friendlyName })
var indices = empty(pool.sessionHostIndices) ? range(0, pool.sessionHostCount) : pool.sessionHostIndices
var workspaceName = pool.workspaceResourceName
var hostPoolName = pool.hostPoolResourceName
var appGroupName = pool.applicationGroupResourceName
var idleMs = idleTimeoutMinutes * 60000
var disconnectedMs = disconnectedTimeoutMinutes * 60000
var desktopUserRoleId = '1d18fff3-a72a-46b5-b4a9-0b38a3cd7e63'
var fileHost = '${fslogixStorageAccountName}.file.core.windows.net'
var fslogixUnc = '\\\\${fileHost}\\${pool.fslogixShareName}'
var fslogixCommand = join([
  'powershell.exe -ExecutionPolicy Unrestricted -NoProfile -Command "'
  'New-Item -Path \'HKLM:\\SOFTWARE\\FSLogix\\Profiles\' -Force | Out-Null; '
  'New-ItemProperty -Path \'HKLM:\\SOFTWARE\\FSLogix\\Profiles\' -Name \'Enabled\' -Value 1 -PropertyType DWord -Force | Out-Null; '
  'New-ItemProperty -Path \'HKLM:\\SOFTWARE\\FSLogix\\Profiles\' -Name \'AccessNetworkAsComputerObject\' -Value 0 -PropertyType DWord -Force | Out-Null; '
  'New-ItemProperty -Path \'HKLM:\\SOFTWARE\\FSLogix\\Profiles\' -Name \'VHDLocations\' -Value \'${fslogixUnc}\' -PropertyType MultiString -Force | Out-Null; '
  'New-Item -Path \'HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows NT\\Terminal Services\' -Force | Out-Null; '
  'New-ItemProperty -Path \'HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows NT\\Terminal Services\' -Name \'MaxIdleTime\' -Value ${idleMs} -PropertyType DWord -Force | Out-Null; '
  'New-ItemProperty -Path \'HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows NT\\Terminal Services\' -Name \'MaxDisconnectionTime\' -Value ${disconnectedMs} -PropertyType DWord -Force | Out-Null; '
  'New-ItemProperty -Path \'HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows NT\\Terminal Services\' -Name \'fResetBroken\' -Value 1 -PropertyType DWord -Force | Out-Null;'
  '"'
], '')

resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2024-04-03' = {
  name: hostPoolName
  location: location
  tags: poolTags
  properties: {
    friendlyName: pool.friendlyName
    hostPoolType: 'Pooled'
    loadBalancerType: 'BreadthFirst'
    maxSessionLimit: pool.maxSessionsLimit
    startVMOnConnect: true
    validationEnvironment: enableUat
    preferredAppGroupType: 'Desktop'
    customRdpProperty: 'drivestoredirect:s:;usbdevicestoredirect:s:;devicestoredirect:s:;camerastoredirect:s:;redirectprinters:i:0;redirectclipboard:i:0;redirectcomports:i:0;redirectsmartcards:i:0;audiomode:i:0;targetisaadjoined:i:1;'
    registrationInfo: {
      expirationTime: registrationTokenExpiration
      registrationTokenOperation: 'Update'
    }
  }
}

resource appGroup 'Microsoft.DesktopVirtualization/applicationGroups@2024-04-03' = {
  name: appGroupName
  location: location
  tags: poolTags
  properties: {
    applicationGroupType: 'Desktop'
    friendlyName: '${pool.friendlyName} Desktop'
    hostPoolArmPath: hostPool.id
    description: '${pool.friendlyName} desktop (${pool.workload}, ${pool.users} users)'
  }
}

resource workspace 'Microsoft.DesktopVirtualization/workspaces@2024-04-03' = {
  name: workspaceName
  location: location
  tags: poolTags
  properties: {
    friendlyName: '${pool.friendlyName} Workspace'
    description: '${pool.friendlyName} AVD workspace'
    publicNetworkAccess: publicNetworkAccessEnabled ? 'Enabled' : 'Disabled'
    applicationGroupReferences: [
      appGroup.id
    ]
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2024-05-01' = [for i in indices: {
  name: 'nic-${pool.abbrev}-${locationShort}-${padLeft(string(i + 1), 2, '0')}'
  location: location
  tags: poolTags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: union({
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
        }, (i == rdpHostIndex && !empty(rdpPublicIpId)) ? {
          publicIPAddress: {
            id: rdpPublicIpId
          }
        } : {})
      }
    ]
  }
}]

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = [for (i, idx) in indices: {
  name: '${pool.abbrev}-${locationShort}-${padLeft(string(i + 1), 2, '0')}'
  location: location
  tags: poolTags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: pool.vmSize
    }
    licenseType: 'Windows_Client'
    securityProfile: {
      securityType: 'TrustedLaunch'
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
      encryptionAtHost: encryptionAtHostEnabled
    }
    osProfile: {
      computerName: '${pool.abbrev}-${locationShort}-${padLeft(string(i + 1), 2, '0')}'
      adminUsername: localAdminUsername
      adminPassword: localAdminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
      }
    }
    storageProfile: {
      osDisk: {
        name: 'osdisk-${pool.abbrev}-${locationShort}-${padLeft(string(i + 1), 2, '0')}'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        diskSizeGB: pool.osDiskSizeGb
        managedDisk: {
          storageAccountType: pool.osDiskType
        }
        deleteOption: 'Delete'
      }
      imageReference: empty(sourceImageId) ? {
        publisher: imagePublisher
        offer: imageOffer
        sku: imageSku
        version: 'latest'
      } : {
        id: sourceImageId
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic[idx].id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}]

resource avdAgent 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = [for (i, idx) in indices: {
  parent: vm[idx]
  name: 'AVDAgentDSC'
  location: location
  properties: {
    publisher: 'Microsoft.Powershell'
    type: 'DSC'
    typeHandlerVersion: '2.83'
    autoUpgradeMinorVersion: true
    settings: {
      modulesUrl: avdDscModulesUrl
      configurationFunction: 'Configuration.ps1\\AddSessionHost'
      properties: {
        hostPoolName: hostPool.name
        aadJoin: true
      }
    }
    protectedSettings: {
      properties: {
        registrationInfoToken: hostPool.properties.registrationInfo.token
      }
    }
  }
}]

resource monitorAgent 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = [for (i, idx) in indices: {
  parent: vm[idx]
  name: 'AzureMonitorWindowsAgent'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorWindowsAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
  }
}]

resource fslogixConfig 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = [for (i, idx) in indices: if (enableFslogix) {
  parent: vm[idx]
  name: 'FSLogixKeyConfig'
  location: location
  dependsOn: [
    avdAgent[idx]
  ]
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    protectedSettings: {
      commandToExecute: fslogixCommand
    }
  }
}]

resource desktopUserAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(pool.accessGroupObjectId)) {
  name: guid(appGroup.id, pool.accessGroupObjectId, desktopUserRoleId)
  scope: appGroup
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', desktopUserRoleId)
    principalId: pool.accessGroupObjectId
    principalType: 'Group'
  }
}

resource hostPoolDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: 'diag-hostpool'
  scope: hostPool
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

resource workspaceDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: 'diag-workspace'
  scope: workspace
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

resource scalingPlan 'Microsoft.DesktopVirtualization/scalingPlans@2024-04-03' = if (enableScalingPlan && pool.sessionHostCount > 0) {
  name: 'sp-${prefix}-${pool.abbrev}-${environment}'
  location: location
  tags: poolTags
  properties: {
    friendlyName: '${pool.friendlyName} scaling'
    description: 'Ramp down to zero hosts so session hosts deallocate when unused.'
    timeZone: 'India Standard Time'
    hostPoolType: 'Pooled'
    exclusionTag: 'excludeFromScaling'
    schedules: [
      {
        name: 'Weekday'
        daysOfWeek: [
          'Monday'
          'Tuesday'
          'Wednesday'
          'Thursday'
          'Friday'
          'Saturday'
          'Sunday'
        ]
        rampUpStartTime: {
          hour: 8
          minute: 0
        }
        rampUpLoadBalancingAlgorithm: 'DepthFirst'
        rampUpMinimumHostsPct: 0
        rampUpCapacityThresholdPct: 80
        peakStartTime: {
          hour: 9
          minute: 0
        }
        peakLoadBalancingAlgorithm: 'DepthFirst'
        rampDownStartTime: {
          hour: 18
          minute: 0
        }
        rampDownLoadBalancingAlgorithm: 'DepthFirst'
        rampDownMinimumHostsPct: 0
        rampDownCapacityThresholdPct: 1
        rampDownWaitTimeMinutes: 15
        rampDownNotificationMessage: 'Save your work. This session host will shut down after you sign out.'
        rampDownStopHostsWhen: 'ZeroSessions'
        rampDownForceLogoffUsers: true
        offPeakStartTime: {
          hour: 20
          minute: 0
        }
        offPeakLoadBalancingAlgorithm: 'DepthFirst'
      }
    ]
    hostPoolReferences: [
      {
        hostPoolArmPath: hostPool.id
        scalingPlanEnabled: true
      }
    ]
  }
}

output workspaceId string = workspace.id
output workspaceName string = workspace.name
output hostPoolId string = hostPool.id
output hostPoolName string = hostPool.name
output applicationGroupId string = appGroup.id
output scalingPlanId string = enableScalingPlan && pool.sessionHostCount > 0 ? scalingPlan!.id : ''
output sessionHostVmIds array = [for (i, idx) in indices: vm[idx].id]
