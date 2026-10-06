param prefix string
param location string
param locationShort string
param environment string
param firewallPrivateIp string
param routeTableName string = ''
param tags object = {}

var resolvedName = empty(routeTableName) ? 'rt-${prefix}-${environment}-${locationShort}' : routeTableName

resource routeTable 'Microsoft.Network/routeTables@2024-05-01' = {
  name: resolvedName
  location: location
  tags: tags
  properties: {
    routes: [
      {
        name: 'default-via-firewall'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: firewallPrivateIp
        }
      }
    ]
  }
}

output routeTableId string = routeTable.id
