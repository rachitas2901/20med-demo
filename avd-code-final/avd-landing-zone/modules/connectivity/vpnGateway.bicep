param gatewayName string
param publicIpName string
param location string
param gatewaySubnetId string
@description('AZ SKU for a new hub. VpnGw2AZ supports Generation1 and Generation2. VpnGw1AZ is Generation1 only and remains valid.')
param sku string = 'VpnGw2AZ'
param generation string = 'Generation2'
param enableActiveActive bool = false
param enableBgp bool = false
param asn int = 65515
param zones array = [
  '1'
  '2'
  '3'
]
param p2sAddressPrefixes array = []
param p2sVpnClientProtocols array = [
  'OpenVPN'
]
param p2sRootCertificateName string = ''

@secure()
param p2sRootCertificatePublicData string = ''
param tags object = {}

var enableP2s = !empty(p2sRootCertificatePublicData) && length(p2sAddressPrefixes) > 0

resource publicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: publicIpName
  location: location
  zones: empty(zones) ? null : zones
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
  tags: tags
}

resource publicIpSecondary 'Microsoft.Network/publicIPAddresses@2024-05-01' = if (enableActiveActive) {
  name: '${publicIpName}-secondary'
  location: location
  zones: empty(zones) ? null : zones
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
  }
  tags: tags
}

resource gateway 'Microsoft.Network/virtualNetworkGateways@2024-05-01' = {
  name: gatewayName
  location: location
  tags: tags
  properties: union({
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    vpnGatewayGeneration: generation
    activeActive: enableActiveActive
    enableBgp: enableBgp
    sku: {
      name: sku
      tier: sku
    }
    ipConfigurations: enableActiveActive ? [
      {
        name: 'ipconfig-0'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: gatewaySubnetId
          }
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
      {
        name: 'ipconfig-1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: gatewaySubnetId
          }
          publicIPAddress: {
            id: publicIpSecondary!.id
          }
        }
      }
    ] : [
      {
        name: 'ipconfig-0'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: gatewaySubnetId
          }
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
  }, enableBgp ? {
    bgpSettings: {
      asn: asn
    }
  } : {}, enableP2s ? {
    vpnClientConfiguration: {
      vpnClientAddressPool: {
        addressPrefixes: p2sAddressPrefixes
      }
      vpnClientProtocols: p2sVpnClientProtocols
      vpnClientRootCertificates: [
        {
          name: p2sRootCertificateName
          properties: {
            publicCertData: p2sRootCertificatePublicData
          }
        }
      ]
    }
  } : {})
}

output gatewayId string = gateway.id
output publicIpResourceId string = publicIp.id
