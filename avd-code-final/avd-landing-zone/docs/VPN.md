# VPN

VPN is not part of this deployment.

`enableVpnGateway` is not a hub parameter. The hub template does not create a VPN gateway, a VPN public IP, a local network gateway, or a VPN connection.

`useHubGatewayTransit` is false. Spoke peering does not request gateway transit and does not use remote gateways.

Workload routes use the hub firewall private IP as the virtual appliance next hop for `0.0.0.0/0`.
