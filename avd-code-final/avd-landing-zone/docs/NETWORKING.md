# Networking

Hub and firewall live in `rg-20med-network-hub-prod-cin`. AVD workloads live in the production spoke. Internet egress from an AVD subnet goes to the hub firewall private IP. NAT Gateway is not used. VPN is not used.

```
Session host in snet-avd-de
  -> route 0.0.0.0/0
  -> hub firewall private IP
  -> allowlisted destination only

Session host
  -> privatelink.file.core.windows.net
  -> private endpoint in snet-privateendpoint
```

The private endpoint subnet has no route table. File traffic is not forced through the firewall.

`snet-management` has the same default route and no virtual machines. It is reserved. No Bastion and no jump host are deployed.

## Address plan

| Network | Name | Prefix |
|---|---|---|
| Hub | `vnet-20med-hub-prod-cin` | `10.20.0.0/16` |
| Firewall data | `AzureFirewallSubnet` | `10.20.1.0/26` |
| Firewall management | `AzureFirewallManagementSubnet` | `10.20.1.64/26` |
| Reserved, no gateway | `GatewaySubnet` | `10.20.2.0/26` |
| Prod spoke | `vnet-20med-avd-prod-cin` | `10.10.0.0/16` |

Hub subnets use Azure's required names. They have no NSG and no route table.

| Spoke subnet | Prefix | Deployed now |
|---|---|---|
| `snet-avd-de` | `10.10.1.0/24` | Yes |
| `snet-avd-prospecting` | `10.10.2.0/24` | No, reserved on the workspace object |
| `snet-avd-sales` | `10.10.3.0/24` | No, reserved |
| `snet-avd-reference` | `10.10.4.0/24` | No, reserved |
| `snet-avd-finance` | `10.10.5.0/24` | No, reserved |
| `snet-privateendpoint` | `10.10.10.0/24` | Yes |
| `snet-management` | `10.10.11.0/24` | Yes, empty |

These ranges do not overlap.

## Peering

The hub template does not create peering. The spoke does not exist yet when the hub is deployed.

`modules/network/peering.bicep` is called twice by the spoke. `useHubGatewayTransit` is false.

Hub side, in the existing hub resource group:

- `allowVirtualNetworkAccess` true
- `allowForwardedTraffic` true
- `allowGatewayTransit` false
- `useRemoteGateways` false

Spoke side, in the spoke resource group, after the hub side exists:

- `allowVirtualNetworkAccess` true
- `allowForwardedTraffic` true
- `allowGatewayTransit` false
- `useRemoteGateways` false

## Routes

Each enabled AVD subnet gets its own route table, for example `rt-avd-de-prod`.

| Route | Prefix | Next hop |
|---|---|---|
| `default-via-firewall` | `0.0.0.0/0` | Virtual appliance, hub firewall private IP |
| `wvd-service-direct` | `WindowsVirtualDesktop` | Internet |

The firewall private IP comes from `ipConfigurations[0]` on the hub firewall. It is not hardcoded. That address is the only next hop configured for workload traffic.

The `WindowsVirtualDesktop` route is intentional. It is more specific than `0.0.0.0/0` and sends AVD control-plane and broker traffic to Internet. GitHub, Fabric, Microsoft 365 business destinations, SQLDBM, and any other internet address stay on the default route to the hub firewall. Set `bypassWindowsVirtualDesktopServiceTag` to false to remove the service-tag route. `snet-privateendpoint` has no route table. `snet-management` uses the same two routes and has no compute.

## Firewall

One Firewall Basic in the hub. The hub template owns the firewall, both public IPs required by Firewall Basic, and the policy resource `afwp-20med-prod-cin`. Policy tier Basic. Threat intelligence mode is Alert. DNS proxy, TLS inspection, IDPS, web categories, and URL filtering are not set. Those public IPs belong to the firewall service. Spoke route tables do not use them.

`rcg-platform` is owned by the hub. Its priority is `10000`. Its source is the prod spoke `10.10.0.0/16`. Those rules cover AVD, Entra, Windows Update, certificates, monitoring, activation, and SMB to the Storage service tag.

The prod spoke adds only its own rule collection groups on that existing policy:

| Group | Owner | Priority |
|---|---|---|
| `rcg-platform` | Hub | 10000 |
| `rcg-avd-files-prod` | Prod spoke | 20000 |
| `rcg-avd-de-prod` | Prod spoke | 30000 |

Workspace groups allow that subnet's SaaS list only. Data Engineering uses source `10.10.1.0/24`. A future Sales group uses only the Sales subnet. The `/16` range is not the source of those SaaS rules.

Additional workspaces use `rcg-avd-<key>-prod` at `30000 + (index * 10)`. The file group stays at 20000. Platform stays at 10000.

`rcg-platform` does not allow GitHub, Fabric, SQLDBM, or the workspace Microsoft 365 list. Those names are only in the Data Engineering workspace group.

A spoke deployment does not redeploy the firewall policy resource. It creates only its own rule collection groups.

## DNS

The prod spoke owns `privatelink.file.core.windows.net` in its own resource group, linked to the prod spoke VNet. The storage account is `st20meddefslogixp`. `linkPrivateDnsToHub` stays false.

Session hosts use Azure DNS (`168.63.129.16`). Firewall Basic cannot be a DNS proxy, so VNet DNS is not pointed at the firewall.

## Monitoring

The prod spoke has its own Log Analytics workspace. The hub does not create one, and the first hub deployment does not wait for that workspace. `logAnalyticsWorkspaceId` on the hub is empty, so firewall diagnostics are off until that value is set on a later, intentional hub deployment. Point it at the prod workspace resource ID after that workspace exists. The spoke template does not write diagnostic settings onto the firewall.

## NSGs

One NSG per enabled AVD subnet, `nsg-avd-de-prod` today. Inbound is deny, including public RDP. There is no outbound deny. SaaS filtering is the firewall's job. NSG diagnostics send `NetworkSecurityGroupEvent` and `NetworkSecurityGroupRuleCounter`. Those are not Network Watcher flow logs. Flow logs are not deployed.

The private endpoint NSG keeps Azure's default rules so a blanket deny does not block the private endpoint.
