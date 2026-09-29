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

subscription_id="$(az account show --query id -o tsv)"
firewall_ip="$(az rest --method get --url "https://management.azure.com/subscriptions/${subscription_id}/resourceGroups/${hub_rg}/providers/Microsoft.Network/azureFirewalls/${firewall_name}?api-version=2024-05-01" --query "properties.ipConfigurations[0].properties.privateIPAddress" -o tsv)"
if [[ -z "${firewall_ip}" || "${firewall_ip}" == "None" ]]; then
  echo "Firewall ${firewall_name} has no data-plane private IP on ipConfigurations[0]. Refusing the spoke run."
  exit 1
fi

if ! az network firewall policy show --resource-group "${hub_rg}" --name "${policy_name}" --query id -o tsv >/dev/null; then
  echo "Firewall policy ${policy_name} does not exist in ${hub_rg}. Deploy the hub before this spoke."
  exit 1
fi

echo "Required hub resources exist. Firewall data-plane private IP is present."
