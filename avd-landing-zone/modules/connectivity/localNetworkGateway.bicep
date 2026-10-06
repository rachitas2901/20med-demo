param location string
param tags object = {}

type localNetworkGatewayType = {
  name: string
  gatewayIpAddress: string
  addressPrefixes: string[]
  bgpAsn: int
  bgpPeeringAddress: string
}

param gateways localNetworkGatewayType[]

resource localGateway 'Microsoft.Network/localNetworkGateways@2024-05-01' = [for item in gateways: {
  name: item.name
  location: location
  tags: tags
  properties: union({
    gatewayIpAddress: item.gatewayIpAddress
    localNetworkAddressSpace: {
      addressPrefixes: item.addressPrefixes
    }
  }, item.bgpAsn > 0 && !empty(item.bgpPeeringAddress) ? {
    bgpSettings: {
      asn: item.bgpAsn
      bgpPeeringAddress: item.bgpPeeringAddress
      peerWeight: 0
    }
  } : {})
}]

output ids array = [for i in range(0, length(gateways)): localGateway[i].id]
output names array = [for item in gateways: item.name]
