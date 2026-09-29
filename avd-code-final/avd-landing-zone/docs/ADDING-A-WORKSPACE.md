# Adding a workspace

Change one object in `parameters/spoke.prod.bicepparam`. Do not edit the modules.

## Enable Prospecting

Set `enabled` to `true` on the Prospecting object. Then set:

- `accessGroupObjectId` to that workspace's Entra group object ID
- `approvedApplicationFqdns` to the hostnames that workspace is allowed to reach
- `sessionHostCount` and `vmSize` to the approved size

Leave Data Engineering as it is. Deploy the same parameter file.

Bicep creates:

- `snet-avd-prospecting`
- `nsg-avd-prospecting-prod`
- `rt-avd-prospecting-prod` with `0.0.0.0/0` to the hub firewall private IP
- host pool, workspace, desktop application group, session hosts, scaling plan
- file share `prospecting-fslogix` on the existing storage account
- SMB Share Contributor on that share when the group object ID is set
- firewall rule collection `rcg-avd-prospecting-prod`, source `10.10.2.0/24` only
- host pool and workspace diagnostics on the existing Log Analytics workspace

Bicep does not create:

- another hub or firewall
- a NAT Gateway
- a VPN gateway
- a new VNet or resource group

Sales, Reference Data, and Finance use the same pattern. Their reserved prefixes are already on the object: `10.10.3.0/24`, `10.10.4.0/24`, and `10.10.5.0/24`.

## Rules that stay separate

Platform rules (AVD agent, Entra, Windows Update, certificates, Azure Files) apply to every enabled subnet.

SaaS rules apply only to the subnet on that workspace object. Prospecting does not receive the Data Engineering GitHub and Fabric list unless those names are copied into Prospecting's `approvedApplicationFqdns`.

## Names

`abbrev` must stay two or three characters. The computer name is `{abbrev}-cin-01`. `prospecting-cin-01` is longer than 15 characters, so Prospecting uses `pr`.

An empty `accessGroupObjectId` skips the role assignment. The pool still deploys, and nobody can sign in until the object ID is set.
