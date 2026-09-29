# 20MED AVD hub and spoke

Subscription deployment for a shared hub and one Azure Virtual Desktop spoke in Central India. Data Engineering is the only enabled workspace.

```
rg-20med-network-hub-prod-cin
  vnet-20med-hub-prod-cin          10.20.0.0/16
    AzureFirewallSubnet            10.20.1.0/26
    AzureFirewallManagementSubnet  10.20.1.64/26
    GatewaySubnet                  10.20.2.0/26    reserved, no VPN gateway
  afw-20med-prod-cin               Firewall Basic

rg-20med-avd-prod-cin
  vnet-20med-avd-prod-cin          10.10.0.0/16
    snet-avd-de                    10.10.1.0/24     HP-DataEngineering, 1 x Standard_D2s_v5
    snet-privateendpoint           10.10.10.0/24    Azure Files private endpoint
    snet-management                10.10.11.0/24    reserved, no jump host, no Bastion
  de-fslogix                       Standard_LRS quota 100 GiB, Entra Kerberos
  law-20med-avd-prod-cin           30 day retention
```

There is no UAT spoke. Spoke routes send `0.0.0.0/0` to the hub firewall private IP.

## Adding a workspace

Edit `avdWorkspaces` in `parameters/spoke.prod.bicepparam`. Set `enabled` to `true` on Prospecting, Sales, Reference Data, or Finance. Bicep then creates that subnet, NSG, route table, host pool, session hosts, FSLogix share, and a firewall rule collection scoped to that subnet. The hub and firewall stay as they are.

Put that workspace's Entra group object ID in `accessGroupObjectId`. Add only that workspace's application FQDNs to `approvedApplicationFqdns`. An empty list gets platform access (AVD, Entra, Windows Update, certificates) and does not inherit Data Engineering's SaaS list.

See `docs/ADDING-A-WORKSPACE.md` and `docs/SCALING-AVD.md`.

## What this deployment does not create

NAT Gateway is not deployed. The hub template does not create a VPN gateway, VPN public IP, local network gateway, or VPN connection. Spoke peering does not use gateway transit. The default route next hop is the hub firewall private IP.

Microsoft Sentinel, Defender for Servers, Key Vault, Bastion, and a management VM are not deployed. Prospecting, Sales, Reference Data, and Finance stay disabled.

## GitHub Actions

| Workflow | What it does |
|---|---|
| `validate-hub.yml` | On a pull request that touches the hub: compile `main-hub.bicep` and what-if the hub. It does not deploy. |
| `deploy-hub.yml` | Manual only. Deploys `parameters/hub.prod.bicepparam` through the GitHub Environment `hub-production`. Add required reviewers on that environment before the first hub run. |
| `validate-spoke.yml` | On a pull request that touches a spoke: compile `parameters/spoke.prod.bicepparam` and what-if production. It does not deploy, and it does not deploy the hub. |
| `deploy-spoke.yml` | Manual only. Deploys `parameters/spoke.prod.bicepparam` through the GitHub Environment `production`. Nothing deploys on push. |

The spoke workflow uses `main-spoke.bicep` and `parameters/spoke.prod.bicepparam` only. It may add that spoke's firewall rule collection groups and that spoke's hub-side peering. It does not change the firewall SKU, replace the firewall, or change hub address space or hub subnets. After `azure/login`, every What-If and deploy job checks that the signed-in subscription and tenant match `AZURE_SUBSCRIPTION_ID` and `AZURE_TENANT_ID`. Spoke jobs also stop if the hub firewall, policy, VNet, or firewall private IP is missing. Details and the role table are in `docs/DEPLOYMENT.md`.

OIDC. No client secret in the repo.

Secrets:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`
- `AVD_LOCAL_ADMIN_PASSWORD`

Optional repository variable: `EXPECTED_SUBSCRIPTION_NAME`. When it is set, the signed-in subscription name must match it. Do not put a subscription ID from a previous validation machine into the repo or into that variable unless it is actually the 20MED target.

The app needs Contributor and User Access Administrator on the subscription, because the template writes role assignments.

Do not deploy the subscription template with `--mode Complete`. Incremental mode is required. Complete mode on a resource group would remove resources the current template does not list.

## Local what-if

Do not run `az deployment sub create` until the parameter file has the real Entra group object IDs and the deployment is approved.

```powershell
$env:AVD_LOCAL_ADMIN_PASSWORD = '<password>'
az login
az account set --subscription <subscription-id>
az deployment sub what-if `
  --location centralindia `
  --template-file main-hub.bicep `
  --parameters parameters/hub.prod.bicepparam

az deployment sub what-if `
  --location centralindia `
  --template-file main-spoke.bicep `
  --parameters parameters/spoke.prod.bicepparam
```

Deploy the hub before the spoke. The spoke reads the hub firewall, hub VNet, and firewall policy with `existing`. A spoke deployment adds its own rule collection groups and its own hub-side peering. The default route uses the hub firewall private IP. It does not replace the firewall.

A spoke What-If run before the hub exists is preliminary. Route tables, rule collection groups, and hub-side peering are not fully predicted until the hub firewall and hub VNet exist. Run that What-If again after the hub deployment and review it before any spoke deploy. The sequence is in `docs/DEPLOYMENT.md`.

## POST-DEPLOYMENT / EXTERNAL POLICY REQUIREMENTS

Bicep does not configure these. They are required for the access tests.

1. Create Entra group `SG-AVD-DataEngineering`. Put its object ID in the Data Engineering `accessGroupObjectId`.

   ```powershell
   az ad group show --group "SG-AVD-DataEngineering" --query id -o tsv
   ```

   Members of that group receive Desktop Virtualization User on the desktop application group and Virtual Machine User Login on the spoke resource group. The template does not create the group.
2. `wvdServicePrincipalObjectId` is the tenant object ID of enterprise app `9cdead84-a844-4324-93f2-b2e6bb768d07`, not the application ID itself.

   ```powershell
   az ad sp show --id 9cdead84-a844-4324-93f2-b2e6bb768d07 --query id -o tsv
   ```

   The template assigns Desktop Virtualization Power On Off Contributor on the spoke resource group. Without that object ID, Start VM on Connect cannot start a deallocated host.
3. Conditional Access stays in Microsoft Graph or the Entra portal:
   - Include `SG-AVD-DataEngineering`.
   - Target Azure Virtual Desktop and Microsoft Azure Windows Virtual Desktop.
   - Grant: require MFA. Do not require a compliant or Entra-joined client device. Consultants use unmanaged laptops.
   - Exclude at least one emergency access account so an administrator cannot lock the tenant out.
4. Session hosts are Entra ID joined by the AVD DSC extension (`aadJoin: true`). They are not AD DS joined, hybrid joined, or Entra Domain Services joined.
5. FSLogix uses Entra Kerberos (`directoryServiceOptions: AADKERB`) and `AccessNetworkAsComputerObject = 0`. After the storage account exists, grant admin consent to its file enterprise app and set the share root ACL. Profiles do not mount until those two steps are done. Profisee, Reltio, and Boomi hostnames stay out of the allowlist until the product is chosen.
6. PIM for privileged admin roles is an Entra setting. This template does not grant Owner or subscription Contributor to AVD users.
7. Fabric workspace roles are outside ARM. Default access should be read or diagnostic. Elevated access is a separate, time-bound Fabric assignment.
8. `HKLM\SOFTWARE\FSLogix\Profiles` and the session time limits are written only by the `FSLogixKeyConfig` Custom Script Extension.
9. The scaling plan can deallocate the single host during ramp-down when minimum hosts is 0% and no sessions remain. Ramp-down starts at 18:00 India Standard Time every day. A host started during the day stays allocated until that ramp-down. Start VM on Connect brings it back only after the Windows Virtual Desktop object ID is set.
10. Session hosts use Azure DNS. Firewall Basic has no DNS proxy. Private endpoint records come from `privatelink.file.core.windows.net` linked to the spoke VNet. HTTPS allow rules use SNI. Personal mail, Dropbox, WeTransfer, social, and streaming sites are blocked because they are not allowlisted.
11. Set `alertEmail` before expecting the firewall health alert. An empty value skips the action group. There is no session-host availability alert, because that metric would fire every time the host is deallocated on purpose.
12. `snet-management` is reserved capacity. No management VM and no Bastion are deployed. `AzureFirewallManagementSubnet` is the Firewall Basic management NIC in the hub, not a jump subnet.
