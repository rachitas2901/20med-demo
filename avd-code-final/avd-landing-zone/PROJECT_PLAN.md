# Data Engineering AVD — Phase 1 plan

Only the Data Engineering workspace is enabled. Prospecting, Sales, Reference Data, and Finance stay in `avdWorkspaces` with `enabled: false` until this phase is accepted in writing. Turning one on reuses the hub, firewall, spoke modules, storage account, and Log Analytics workspace.

| # | Work | Hours | Output |
|---|---|---:|---|
| 1 | Assessment and planning | 18 | Approved address plan, SKU check, access list |
| 2 | IaC and pipeline | 44 | Bicep modules, GitHub repo, what-if on pull request, production approval |
| 3 | Azure foundation | 22 | Hub from main-hub.bicep, Firewall Basic, then the spoke and Log Analytics |
| 4 | Workspace | 46 | Data Engineering host pool in the prod spoke, one D2s v5 host, Start VM on Connect |
| 5 | Profiles | 17 | `de-fslogix` share and private endpoint |
| 6 | Firewall and session controls | 34 | Deny-by-default egress through the hub firewall, approved FQDNs, redirection locked down |
| 7 | Monitoring and cost | 22 | Firewall diagnostics, 30 day retention, deallocation checks |
| 8 | Testing | 14 | Sign-in, blocked site in firewall logs, profile survives restart |
| 9 | Documentation and handover | 43 | As-built, runbook, repo and pipeline owned by 20MED |
| | Total | 260 | |

Sequence inside the build:

1. GitHub organisation, app registration, federated credentials, `production` environment reviewer.
2. `deploymentPhase = landing_zone` for hub, spoke network, firewall, files, and logs.
3. `deploymentPhase = avd` for the Data Engineering pool and session host.
4. Prove an approved site works and an unapproved site is logged as denied.
5. Hand the repo, pipeline, and deployment app to 20MED. Remove vendor standing access.
