param location string
param tags object = {}
param gatewayName string
param publicIpName string
param gatewaySubnetId string
param sku string
param generation string
param enableBgp bool
param enableActiveActive bool = false
param asn int
param zones array
param enableSiteToSiteConnection bool

type localNetworkGatewayType = {
  name: string
  gatewayIpAddress: string
  addressPrefixes: string[]
  bgpAsn: int
  bgpPeeringAddress: string
}

type vpnConnectionType = {
  name: string
  localNetworkGatewayName: string
  enableBgp: bool
}

param localNetworkGateways localNetworkGatewayType[]
param vpnConnections vpnConnectionType[]

@secure()
param vpnSharedSecrets object

@secure()
param p2sRootCertificatePublicData string = ''
param p2sAddressPrefixes array = []
param p2sRootCertificateName string = ''

module gateway 'vpnGateway.bicep' = {
  name: 'vpn-gateway'
  params: {
    gatewayName: gatewayName
    publicIpName: publicIpName
    location: location
    gatewaySubnetId: gatewaySubnetId
    sku: sku
    generation: generation
    enableBgp: enableBgp
    enableActiveActive: enableActiveActive
    asn: asn
    zones: zones
    p2sAddressPrefixes: p2sAddressPrefixes
    p2sRootCertificateName: p2sRootCertificateName
    p2sRootCertificatePublicData: p2sRootCertificatePublicData
    tags: tags
  }
}

module localGateways 'localNetworkGateway.bicep' = if (enableSiteToSiteConnection && length(localNetworkGateways) > 0) {
  name: 'local-network-gateways'
  params: {
    location: location
    tags: tags
    gateways: localNetworkGateways
  }
}

module siteToSite 'vpnConnection.bicep' = if (enableSiteToSiteConnection && length(vpnConnections) > 0 && length(localNetworkGateways) > 0) {
  name: 'vpn-connections'
  params: {
    location: location
    tags: tags
    virtualNetworkGatewayId: gateway.outputs.gatewayId
    localNetworkGatewayIds: localGateways!.outputs.ids
    localNetworkGatewayNames: localGateways!.outputs.names
    connections: vpnConnections
    sharedSecrets: vpnSharedSecrets
  }
}

output gatewayId string = gateway.outputs.gatewayId
