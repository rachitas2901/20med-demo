param accessGroupObjectIds string[] = []
param wvdServicePrincipalObjectId string = ''

var vmUserLoginRoleId = 'fb879df8-f326-4884-b1cf-06f3ad86be52'
var powerOnOffRoleId = '40c5ff49-9181-41f8-ae61-143b0e78555e'

resource vmUserLogin 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for principalId in accessGroupObjectIds: if (!empty(principalId)) {
  name: guid(resourceGroup().id, principalId, vmUserLoginRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', vmUserLoginRoleId)
    principalId: principalId
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
