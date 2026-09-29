# Scaling AVD

Scale a workspace by editing its object. The host that already exists keeps its name.

## More hosts

`sessionHostCount: 1` creates `de-cin-01`.

`sessionHostCount: 3` creates `de-cin-01`, `de-cin-02`, and `de-cin-03`.

Host 01 is not replaced when the count goes from 1 to 3. The name is `{abbrev}-{locationShort}-{nn}`. Windows limits that name to 15 characters.

`sessionHostCount: 0` keeps the host pool and does not deploy session hosts. The scaling plan is also skipped, because there is nothing to start.

## Fewer hosts

This repository deploys in incremental mode. Reducing `sessionHostCount` from 3 to 1 stops managing `de-cin-02` and `de-cin-03`. It does not delete them.

Before treating the scale-down as finished, delete the extra virtual machines, NICs, and OS disks in the spoke resource group. Deleting the resource group is not required.

Do not switch the subscription deployment to complete mode to force that cleanup. Complete mode can delete unrelated resources in the group, including the other workspace once it exists.

## Size and sessions

`vmSize` changes the session host size the next time that VM is deployed. Changing the size of a host that already exists replaces that virtual machine.

`maxSessionLimit` changes how many sessions the host pool accepts. It does not add virtual machines.

`loadBalancerType` is `DepthFirst` for Data Engineering. The scaling plan also uses DepthFirst, with a minimum of 0% of hosts, so the single host can deallocate at 18:00 India Standard Time when no sessions remain.
