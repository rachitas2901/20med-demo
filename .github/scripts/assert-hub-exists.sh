#!/usr/bin/env bash
set -euo pipefail

hub_rg="rg-20med-network-hub-prod-cin"
hub_vnet="vnet-20med-hub-prod-cin"
firewall_name="afw-20med-prod-cin"
policy_name="afwp-20med-prod-cin"

if [[ "$(az group exists --name "${hub_rg}")" != "true" ]]; then
  echo "Hub resource group ${hub_rg} does not exist. Deploy the hub before this spoke. The spoke template will not create it."
  exit 1
fi

if ! az network vnet show --resource-group "${hub_rg}" --name "${hub_vnet}" --query id -o tsv >/dev/null; then
  echo "Hub VNet ${hub_vnet} does not exist in ${hub_rg}. Deploy the hub before this spoke."
  exit 1
fi

if ! az network firewall show --resource-group "${hub_rg}" --name "${firewall_name}" --query id -o tsv >/dev/null; then
  echo "Azure Firewall ${firewall_name} does not exist in ${hub_rg}. Deploy the hub before this spoke."
  exit 1
fi

firewall_ip="$(az network firewall show --resource-group "${hub_rg}" --name "${firewall_name}" --query "ipConfigurations[0].privateIpAddress" -o tsv)"
if [[ -z "${firewall_ip}" || "${firewall_ip}" == "None" ]]; then
  echo "Firewall ${firewall_name} has no data-plane private IP on ipConfigurations[0]. Refusing the spoke run."
  exit 1
fi

if ! az network firewall policy show --resource-group "${hub_rg}" --name "${policy_name}" --query id -o tsv >/dev/null; then
  echo "Firewall policy ${policy_name} does not exist in ${hub_rg}. Deploy the hub before this spoke."
  exit 1
fi

echo "Required hub resources exist. Firewall data-plane private IP is present."
