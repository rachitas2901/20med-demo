#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${EXPECTED_SUBSCRIPTION_ID:-}" || -z "${EXPECTED_TENANT_ID:-}" ]]; then
  echo "AZURE_SUBSCRIPTION_ID and AZURE_TENANT_ID must be set before What-If or deployment."
  exit 1
fi

actual_subscription="$(az account show --query id -o tsv)"
actual_tenant="$(az account show --query tenantId -o tsv)"
actual_name="$(az account show --query name -o tsv)"

if [[ "${actual_subscription}" != "${EXPECTED_SUBSCRIPTION_ID}" ]]; then
  echo "Subscription check failed. The signed-in subscription does not match AZURE_SUBSCRIPTION_ID."
  echo "Signed-in subscription: ${actual_subscription} (${actual_name})"
  exit 1
fi

if [[ "${actual_tenant}" != "${EXPECTED_TENANT_ID}" ]]; then
  echo "Tenant check failed. The signed-in tenant does not match AZURE_TENANT_ID."
  echo "Signed-in tenant: ${actual_tenant}"
  exit 1
fi

if [[ -n "${EXPECTED_SUBSCRIPTION_NAME:-}" && "${actual_name}" != "${EXPECTED_SUBSCRIPTION_NAME}" ]]; then
  echo "Subscription name check failed. The signed-in subscription name does not match EXPECTED_SUBSCRIPTION_NAME."
  echo "Signed-in name: ${actual_name}"
  exit 1
fi

echo "Azure subscription and tenant match the configured 20MED target."
