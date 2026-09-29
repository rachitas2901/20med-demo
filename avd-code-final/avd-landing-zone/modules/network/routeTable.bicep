param routeTableName string
param location string
@minLength(1)
@description('Data-plane private IP of the hub firewall. An empty value is rejected so the default route cannot be created with a blank next hop.')
param firewallPrivateIp string
@description('Sends the WindowsVirtualDesktop service tag direct to Internet. More specific than 0.0.0.0/0, so GitHub, Fabric, and other SaaS still hit the firewall.')
param bypassWindowsVirtualDesktopServiceTag bool = true
param tags object = {}

resource routeTable 'Microsoft.Network/routeTables@2024-05-01' = {
  name: routeTableName
  location: location
  tags: tags
  properties: {
    disableBgpRoutePropagation: false
  }
}

resource defaultRoute 'Microsoft.Network/routeTables/routes@2024-05-01' = {
  parent: routeTable
  name: 'default-via-firewall'
  properties: {
    addressPrefix: '0.0.0.0/0'
    nextHopType: 'VirtualAppliance'
    nextHopIpAddress: firewallPrivateIp
  }
}

resource wvdRoute 'Microsoft.Network/routeTables/routes@2024-05-01' = if (bypassWindowsVirtualDesktopServiceTag) {
  parent: routeTable
  name: 'wvd-service-direct'
  properties: {
    addressPrefix: 'WindowsVirtualDesktop'
    nextHopType: 'Internet'
  }
}

output routeTableId string = routeTable.id
