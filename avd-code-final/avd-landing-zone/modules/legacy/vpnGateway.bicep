param prefix string
param location string
param locationShort string
param environment string
param gatewaySubnetId string
param sku string = 'VpnGw1AZ'
param p2sAddressSpace array = [
  '172.16.201.0/24'
]
param p2sRootCertificateName string = 'P2SRootCert'

@secure()
param p2sRootCertificatePublicData string = ''
param p2sVpnClientProtocols array = [
  'OpenVPN'
]
param zones array = [
  '1'
  '2'
  '3'
]
param tags object = {}

var generation = contains(sku, 'VpnGw1') ? 'Generation1' : 'Generation2'

resource publicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'pip-${prefix}-vpngw'
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
  name: 'vgw-${prefix}-${environment}-${locationShort}'
  location: location
  tags: tags
  properties: union({
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    vpnGatewayGeneration: generation
    activeActive: false
    enableBgp: false
    sku: {
      name: sku
      tier: sku
    }
    ipConfigurations: [
      {
        name: 'vnetGatewayConfig'
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
  }, empty(p2sRootCertificatePublicData) ? {} : {
    vpnClientConfiguration: {
      vpnClientAddressPool: {
        addressPrefixes: p2sAddressSpace
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
  })
}

output gatewayId string = gateway.id
output publicIp string = publicIp.properties.ipAddress
