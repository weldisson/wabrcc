#!/usr/bin/env bash
set -euo pipefail

# Deploy a tenant as its own namespace with dedicated Deployment/Service/Ingress
# Usage: ./scripts/deploy_tenant.sh TENANT [REPLICAS] [DOMAIN_BASE]
# Requires: k3s installed on host; docker available to build image; env var DATABASE_URL_PREFIX set
# Optional: INIT_DB=true will also create the tenant database (requires DATABASE_ADMIN_URL)

TENANT=${1:-}
REPLICAS=${2:-2}
DOMAIN_BASE=${3:-wabr.cc}

if [[ -z "${TENANT}" ]]; then
  echo "Usage: $0 TENANT [REPLICAS] [DOMAIN_BASE]"
  exit 1
fi

if [[ -z "${DATABASE_URL_PREFIX:-}" ]]; then
  echo "ERROR: DATABASE_URL_PREFIX not set. Example: export DATABASE_URL_PREFIX='postgresql://postgres:xxx@free-database.cukfpauavjwz.us-east-1.rds.amazonaws.com:5432/'"
  exit 1
fi

if ! command -v kubectl >/dev/null 2>&1; then
  echo "ERROR: kubectl not found. Install k3s first with scripts/install_k3s.sh"
  exit 1
fi

IMAGE_REPO="wabrcc/healthpro-site"
IMAGE_TAG="${TENANT}-$(date +%Y%m%d%H%M%S)"
IMAGE_FULL="${IMAGE_REPO}:${IMAGE_TAG}"

HOST="${TENANT}.${DOMAIN_BASE}"
NAMESPACE="tenant-${TENANT}"
DATABASE_URL="${DATABASE_URL_PREFIX}${TENANT}"

# SSL defaults for runtime (can be overridden by env before calling the script)
DATABASE_SSL=${DATABASE_SSL:-true}
DATABASE_SSL_REJECT_UNAUTHORIZED=${DATABASE_SSL_REJECT_UNAUTHORIZED:-true}
DATABASE_SSL_CA_PATH=${DATABASE_SSL_CA_PATH:-/app/rds-bundle.pem}

# Optional DB initialization controls
INIT_DB=${INIT_DB:-false}
DEFAULT_ADMIN_EMAIL=${DEFAULT_ADMIN_EMAIL:-"admin@${TENANT}.${DOMAIN_BASE}"}
DEFAULT_ADMIN_PASSWORD=${DEFAULT_ADMIN_PASSWORD:-"ChangeMe123!"}

export TENANT
export HOST
export NAMESPACE
export REPLICAS
export IMAGE_FULL
export DATABASE_URL
export DATABASE_SSL
export DATABASE_SSL_REJECT_UNAUTHORIZED
export DATABASE_SSL_CA_PATH

echo "[1/6] Building image ${IMAGE_FULL} from ./healthProfessionalSite ..."
docker build -t "${IMAGE_FULL}" ./healthProfessionalSite

echo "[2/6] Importing image into k3s containerd..."
docker save "${IMAGE_FULL}" | sudo k3s ctr images import -

# [2.5/6] Optionally create DB and initialize schema/data
if [ "${INIT_DB}" = "true" ]; then
  echo "[2.5/6] INIT_DB=true - Creating database '${TENANT}' and running db-init..."
  if [[ -z "${DATABASE_ADMIN_URL:-}" ]]; then
    echo "ERROR: DATABASE_ADMIN_URL not set. Example: export DATABASE_ADMIN_URL='postgresql://postgres:xxx@host:5432/postgres'" >&2
    exit 1
  fi
  # Create database if not exists (using postgres client image)
  ./scripts/create_tenant_db.sh "${TENANT}"

  # Run db-init.ts inside a Node container with CA bundle
  docker run --rm \
    -e DATABASE_URL="${DATABASE_URL}" \
    -e DATABASE_SSL="${DATABASE_SSL}" \
    -e DATABASE_SSL_REJECT_UNAUTHORIZED="${DATABASE_SSL_REJECT_UNAUTHORIZED}" \
    -e DATABASE_SSL_CA_PATH=/tmp/rds-bundle.pem \
    -e DEFAULT_ADMIN_EMAIL="${DEFAULT_ADMIN_EMAIL}" \
    -e DEFAULT_ADMIN_PASSWORD="${DEFAULT_ADMIN_PASSWORD}" \
    -v "$PWD/healthProfessionalSite":/app \
    -w /app node:20-alpine sh -lc "\
      set -e; \
      apk add --no-cache curl python3 make g++; \
      curl -s https://truststore.pki.rds.amazonaws.com/us-east-1/us-east-1-bundle.pem -o /tmp/rds-bundle.pem; \
      (npm ci || npm i); \
      npx tsx server/db-init.ts"
fi

echo "[3/6] Rendering Kubernetes manifests..."
WORKDIR="$(mktemp -d)"
trap 'rm -rf "${WORKDIR}"' EXIT

mkdir -p "${WORKDIR}"
for f in namespace.yaml pvc.yaml deployment.yaml service.yaml ingress.yaml; do
  envsubst < "./infra/k8s/templates/${f}" > "${WORKDIR}/${f}"
done

echo "[4/6] Applying manifests to cluster (namespace: ${NAMESPACE})..."
kubectl apply -f "${WORKDIR}/namespace.yaml"
kubectl -n "${NAMESPACE}" apply -f "${WORKDIR}/pvc.yaml"
kubectl -n "${NAMESPACE}" apply -f "${WORKDIR}/deployment.yaml"
kubectl -n "${NAMESPACE}" apply -f "${WORKDIR}/service.yaml"
kubectl -n "${NAMESPACE}" apply -f "${WORKDIR}/ingress.yaml"

echo "[5/6] Waiting for rollout..."
kubectl -n "${NAMESPACE}" rollout status deploy/${TENANT}-app --timeout=180s

echo "[6/6] Success"
cat <<EOF

Tenant deployed
- URL: http://${HOST}
- Namespace: ${NAMESPACE}
- Replicas: ${REPLICAS}
- Image: ${IMAGE_FULL}
- Database: ${DATABASE_URL}

To update after code changes, rerun this script with the same TENANT.
To remove, run: ./scripts/delete_tenant.sh ${TENANT}

EOF


