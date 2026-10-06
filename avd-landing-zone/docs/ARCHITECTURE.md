# Architecture

Central India. One shared hub. One production spoke. One firewall. No VPN gateway. No NAT Gateway. Spoke default routes use the hub firewall private IP.

```
                         Internet
                            |
                    Azure Firewall Basic
                            |
        rg-20med-network-hub-prod-cin
                  |
       vnet-20med-hub-prod-cin  10.20.0.0/16
                  |
             VNet peering
                  |
        vnet-20med-avd-prod-cin
             10.10.0.0/16
        rg-20med-avd-prod-cin
```

The hub pipeline owns the hub resource group, hub VNet, firewall subnets, GatewaySubnet, Azure Firewall, firewall policy, `rcg-platform`, and the firewall public IPs that Azure Firewall Basic requires. `GatewaySubnet` is reserved and has no VPN gateway. The hub template does not create a VPN gateway, VPN public IP, local network gateway, or VPN connection.

A spoke pipeline may create only its own firewall rule collection groups on the existing policy, and its own hub-to-spoke peering. It references the firewall, hub VNet, and policy with `existing`. It does not change the firewall SKU, replace the firewall, or change hub address space or hub subnets. Peering has gateway transit off and `useRemoteGateways` off. Azure RBAC cannot, by itself, stop an identity that may write rule groups on the shared policy from editing `rcg-platform`. Use the narrow roles in `docs/DEPLOYMENT.md`.

Hub outputs used by operators:

- `hubVnetId`
- `firewallPrivateIp`
- `firewallPolicyId`

The spoke reads the same resources by name. Route tables use `firewallPrivateIp` as the virtual appliance next hop.

## Resource groups

| Resource group | Contents |
|---|---|
| `rg-20med-network-hub-prod-cin` | Hub VNet, Firewall Basic, firewall policy, firewall public IPs, hub-side peering |
| `rg-20med-avd-prod-cin` | Prod spoke, workload subnets, NSGs, route tables, AVD, FSLogix, private DNS, Log Analytics, spoke-side peering |

There is no UAT resource group and no resource group per host pool.

## Where new workspaces land

A new workspace is another subnet in the existing spoke. Session hosts stay in the spoke resource group. They do not get a new VNet or firewall.

Network detail is in `docs/NETWORKING.md`.
