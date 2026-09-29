param prefix string
param location string
param locationShort string
param environment string
param storageAccountId string
param storageAccountName string
param fileShareName string
param retentionDaily int = 180
param retentionWeekly int = 12
param retentionMonthly int = 12
param timezone string = 'UTC'
param tags object = {}

var scheduleTime = '2026-01-01T23:00:00Z'
var containerName = 'StorageContainer;storage;${resourceGroup().name};${storageAccountName}'

resource vault 'Microsoft.RecoveryServices/vaults@2024-04-01' = {
  name: 'rsv-${prefix}-${environment}-${locationShort}'
  location: location
  tags: tags
  sku: {
    name: 'RS0'
    tier: 'Standard'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    publicNetworkAccess: 'Disabled'
    securitySettings: {
      immutabilitySettings: {
        state: 'Unlocked'
      }
    }
    redundancySettings: {
      standardTierStorageRedundancy: 'LocallyRedundant'
    }
  }
}

resource backupPolicy 'Microsoft.RecoveryServices/vaults/backupPolicies@2024-04-01' = {
  parent: vault
  name: 'policy-fileshare-daily'
  properties: {
    backupManagementType: 'AzureStorage'
    workLoadType: 'AzureFileShare'
    timeZone: timezone
    schedulePolicy: {
      schedulePolicyType: 'SimpleSchedulePolicy'
      scheduleRunFrequency: 'Daily'
      scheduleRunTimes: [
        scheduleTime
      ]
    }
    retentionPolicy: {
      retentionPolicyType: 'LongTermRetentionPolicy'
      dailySchedule: {
        retentionTimes: [
          scheduleTime
        ]
        retentionDuration: {
          count: retentionDaily
          durationType: 'Days'
        }
      }
      weeklySchedule: {
        daysOfTheWeek: [
          'Sunday'
        ]
        retentionTimes: [
          scheduleTime
        ]
        retentionDuration: {
          count: retentionWeekly
          durationType: 'Weeks'
        }
      }
      monthlySchedule: {
        retentionScheduleFormatType: 'Weekly'
        retentionScheduleWeekly: {
          daysOfTheWeek: [
            'Sunday'
          ]
          weeksOfTheMonth: [
            'First'
          ]
        }
        retentionTimes: [
          scheduleTime
        ]
        retentionDuration: {
          count: retentionMonthly
          durationType: 'Months'
        }
      }
    }
  }
}

resource protectionContainer 'Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers@2024-04-01' = {
  name: '${vault.name}/Azure/${containerName}'
  properties: {
    backupManagementType: 'AzureStorage'
    containerType: 'StorageContainer'
    sourceResourceId: storageAccountId
    protectedItemCount: 0
  }
}

resource protectedShare 'Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems@2024-04-01' = {
  parent: protectionContainer
  name: 'AzureFileShare;${fileShareName}'
  properties: {
    protectedItemType: 'AzureFileShareProtectedItem'
    policyId: backupPolicy.id
    sourceResourceId: '${storageAccountId}/fileServices/default/shares/${fileShareName}'
  }
}

output vaultName string = vault.name
output vaultId string = vault.id
