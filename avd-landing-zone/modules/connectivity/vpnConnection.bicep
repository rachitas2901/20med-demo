param location string
param virtualNetworkGatewayId string
param localNetworkGatewayIds array
param localNetworkGatewayNames array
param tags object = {}

type vpnConnectionType = {
  name: string
  localNetworkGatewayName: string
  enableBgp: bool
}

param connections vpnConnectionType[]

@secure()
param sharedSecrets object

resource connection 'Microsoft.Network/connections@2024-05-01' = [for item in connections: if (indexOf(localNetworkGatewayNames, item.localNetworkGatewayName) >= 0 && !empty(localNetworkGatewayIds[indexOf(localNetworkGatewayNames, item.localNetworkGatewayName)])) {
  name: item.name
  location: location
  tags: tags
  properties: {
    connectionType: 'IPsec'
    #disable-next-line BCP035
    virtualNetworkGateway1: {
      id: virtualNetworkGatewayId
    }
    #disable-next-line BCP035
    localNetworkGateway2: {
      id: localNetworkGatewayIds[indexOf(localNetworkGatewayNames, item.localNetworkGatewayName)]
    }
    sharedKey: sharedSecrets[item.name]
    enableBgp: item.enableBgp
  }
}]
