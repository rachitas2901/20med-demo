# Deployment safety

The hub and spoke templates stay separate. This page is the ownership and rollout contract.

## Who owns which hub resource

The hub pipeline (`deploy-hub.yml`, `main-hub.bicep`, `parameters/hub.prod.bicepparam`) owns:

- `rg-20med-network-hub-prod-cin`
- `vnet-20med-hub-prod-cin`
- `AzureFirewallSubnet`, `AzureFirewallManagementSubnet`, `GatewaySubnet`
- Azure Firewall `afw-20med-prod-cin`
- Firewall policy `afwp-20med-prod-cin`
- Platform rule collection group `rcg-platform`
- Firewall public IPs required by Azure Firewall Basic

A spoke pipeline may create only these resources in the hub group:

- Its own firewall policy rule collection groups (`rcg-avd-files-<environment>` and `rcg-avd-<key>-<environment>`)
- Its own hub-to-spoke peering (`peer-to-<spoke-vnet-name>` on the hub VNet)

A spoke pipeline must not change the firewall SKU, replace the firewall, or change the hub address space or hub subnets. The spoke template marks the hub resource group, hub VNet, and firewall as `existing`, so it does not construct them. There is no UAT spoke.

Azure role assignment on the firewall policy cannot see a rule-group name that does not exist yet. An identity that can write rule collection groups on that policy can also change `rcg-platform`. Do not grant the spoke identity Contributor on the hub resource group. Use the roles below.

## Pipeline guards

`deploy-hub.yml` is `workflow_dispatch` only. It deploys `parameters/hub.prod.bicepparam` through the GitHub environment `hub-production`. It has no push trigger.

`deploy-spoke.yml` is `workflow_dispatch` only. It deploys `parameters/spoke.prod.bicepparam` through the GitHub environment `production`. There is no UAT target and no template-path input.

Every What-If and deploy job logs in with OIDC, then runs `assert-azure-context.sh`. The signed-in subscription must equal secret `AZURE_SUBSCRIPTION_ID`. The signed-in tenant must equal secret `AZURE_TENANT_ID`. If repository variable `EXPECTED_SUBSCRIPTION_NAME` is set, the subscription name must match it. A mismatch stops the job before What-If or deployment.

Spoke What-If and spoke deploy then run `assert-hub-exists.sh`. The job fails if any of these are missing: `rg-20med-network-hub-prod-cin`, `vnet-20med-hub-prod-cin`, `afw-20med-prod-cin`, `afwp-20med-prod-cin`, or the firewall data-plane private IP on `ipConfigurations[0]`. The spoke workflow does not create those resources. It does not require a VPN gateway.

No subscription ID from an earlier local validation is stored in this repo. Configure the secrets to the 20MED subscription and tenant before the first run.

## Spoke identity permissions

The hub identity deploys the hub. Recommended scope is Contributor and User Access Administrator on `rg-20med-network-hub-prod-cin`, plus permission to create that resource group and a subscription deployment. That identity is not used by the spoke workflows.

The spoke identity needs Contributor and User Access Administrator on its own spoke resource group, because the template creates the spoke resources and the Entra role assignments. The deployment is subscription-scoped and creates the spoke resource group, so the identity also needs subscription deployment write and resource-group create. That is not Contributor on the hub resource group.

Cross-resource-group writes use custom roles. Built-in Network Contributor on the hub VNet would also allow subnet changes, including the firewall subnets, so it is not the recommended role.

| Operation | Resource | Required action | Recommended scope | Recommended role |
|---|---|---|---|---|
| Create the spoke resource group and subscription deployment | Subscription | `Microsoft.Resources/subscriptions/resourceGroups/write`, `Microsoft.Resources/deployments/write` | Subscription | Custom role, spoke bootstrap |
| Create and update spoke resources | Spoke resource group | Resource write for network, compute, desktop virtualization, storage, insights | `rg-20med-avd-prod-cin` | Contributor |
| Assign AVD and file roles | Spoke resource group and file share | `Microsoft.Authorization/roleAssignments/write` | Same spoke resource group | User Access Administrator |
| Read the hub firewall private IP | `afw-20med-prod-cin` | `Microsoft.Network/azureFirewalls/read` | That firewall | Custom role, or Reader on the firewall |
| Run the nested deployment that adds peering and rule groups | Hub resource group | `Microsoft.Resources/deployments/write`, `Microsoft.Resources/deployments/read` | `rg-20med-network-hub-prod-cin` | Custom role limited to deployments and resource-group read |
| Create this spoke's hub-side peering | Hub VNet | `Microsoft.Network/virtualNetworks/read`, `Microsoft.Network/virtualNetworks/peer/action`, `Microsoft.Network/virtualNetworks/virtualNetworkPeerings/read`, `write`, `delete` | `vnet-20med-hub-prod-cin` | Custom role. Do not use Network Contributor here |
| Create this spoke's rule collection groups | Firewall policy | `Microsoft.Network/firewallPolicies/read`, `Microsoft.Network/firewallPolicies/ruleCollectionGroups/read`, `write`, `delete` | `afwp-20med-prod-cin` | Custom role. Do not include `firewallPolicies/write` or `azureFirewalls/write` |

These roles are not created by the Bicep templates.

## Firewall private IP

Spoke route tables take `hubFirewall.properties.ipConfigurations[0].properties.privateIPAddress`. That element is the data-plane address on `AzureFirewallSubnet`. The management NIC is a different property and is not used as the next hop. The route module rejects an empty string. The spoke pipeline also refuses to continue when that address is missing.

## Routing and peering in the templates

Enabled AVD subnets and `snet-management` have `0.0.0.0/0` to VirtualAppliance at the hub firewall private IP, and `WindowsVirtualDesktop` to Internet. `snet-privateendpoint` has no route table. `AzureFirewallSubnet`, `AzureFirewallManagementSubnet`, and `GatewaySubnet` are created with no route table and no NSG.

Hub to spoke and spoke to hub both have virtual network access on and forwarded traffic on. Gateway transit and `useRemoteGateways` are off, because `useHubGatewayTransit` is false and no VPN gateway is deployed. The spoke peering depends on the hub peering. Prod peering is `peer-to-vnet-20med-avd-prod-cin` on the hub and `peer-to-vnet-20med-hub-prod-cin` in the prod spoke.

## Private DNS and monitoring

The prod spoke keeps its own file private DNS zone and its own Log Analytics workspace. Hub firewall diagnostics stay off on the first hub deployment. After the prod workspace exists, a later hub deployment may set `logAnalyticsWorkspaceId` to that workspace. The spoke does not need to be deployed again for that, and the hub does not need the spoke in order to be created.

## VPN and NAT

No NAT Gateway is deployed. The hub template does not create a VPN gateway, a VPN public IP, a local network gateway, or a VPN connection. Workload routes use the hub firewall private IP only.

## First deployment sequence

The spoke What-If that was run before the hub existed is preliminary. It did not expand route tables, hub-side peering, or firewall rule groups, because those values come from the hub. Do not treat that preview as the spoke deployment gate.

1. Sign in to the 20MED tenant and subscription configured in `AZURE_TENANT_ID` and `AZURE_SUBSCRIPTION_ID`.
2. Deploy the hub with `deploy-hub.yml` after `hub-production` reviewers approve it.
3. Confirm the hub resource group, VNet, firewall, firewall policy, and platform rule group are healthy, and that the firewall has a data-plane private IP. Confirm no VPN gateway and no NAT gateway were created.
4. Run spoke ARM validate with `parameters/spoke.prod.bicepparam`.
5. Run spoke What-If again, now that the hub exists. This is the authoritative spoke preview. It must show the real firewall private IP, the route tables, this spoke's rule collection groups, and the hub-side peering.
6. Review that What-If. Confirm it does not replace the firewall, and that disabled workspaces are absent.
7. After that review and the required Entra values are set, deploy the production spoke.

The spoke is not deployment-ready until step 5 has been run.

