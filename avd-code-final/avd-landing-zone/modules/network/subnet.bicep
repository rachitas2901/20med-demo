param vnetName string
param subnetName string
param addressPrefix string
param nsgId string = ''
param routeTableId string = ''
param enableStorageServiceEndpoint bool = false
param privateEndpointNetworkPolicies string = 'Enabled'

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' existing = {
  name: vnetName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2024-05-01' = {
  parent: vnet
  name: subnetName
  properties: union({
    addressPrefix: addressPrefix
    privateEndpointNetworkPolicies: privateEndpointNetworkPolicies
  }, empty(nsgId) ? {} : {
    networkSecurityGroup: {
      id: nsgId
    }
  }, empty(routeTableId) ? {} : {
    routeTable: {
      id: routeTableId
    }
  }, enableStorageServiceEndpoint ? {
    serviceEndpoints: [
      {
        service: 'Microsoft.Storage'
      }
    ]
  } : {})
}

output subnetId string = subnet.id
output subnetName string = subnet.name
