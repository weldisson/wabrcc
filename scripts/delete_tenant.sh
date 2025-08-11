#!/usr/bin/env bash
set -euo pipefail

# Delete a tenant namespace and all its resources
# Usage: ./scripts/delete_tenant.sh TENANT

TENANT=${1:-}
if [[ -z "${TENANT}" ]]; then
  echo "Usage: $0 TENANT"
  exit 1
fi

NAMESPACE="tenant-${TENANT}"
echo "Deleting namespace ${NAMESPACE}..."
kubectl delete namespace "${NAMESPACE}" --ignore-not-found
echo "Done."


