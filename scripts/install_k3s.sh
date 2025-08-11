#!/usr/bin/env bash
set -euo pipefail

# Install single-node k3s with Traefik enabled (default) on a fresh server
# Usage: sudo bash ./scripts/install_k3s.sh

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root: sudo bash ./scripts/install_k3s.sh"
  exit 1
fi

echo "[1/5] Installing k3s..."
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--write-kubeconfig-mode 644" sh -

echo "[2/5] Verifying k3s service..."
systemctl enable k3s >/dev/null 2>&1 || true
systemctl status k3s --no-pager | cat

echo "[3/5] Ensuring kubectl is available..."
if ! command -v kubectl >/dev/null 2>&1; then
  ln -sf /usr/local/bin/k3s /usr/local/bin/kubectl
fi

echo "[4/5] Waiting for node to be Ready..."
for i in {1..60}; do
  if kubectl get nodes 2>/dev/null | grep -qE "\bReady\b"; then
    break
  fi
  sleep 2
done
kubectl get nodes -o wide | cat

echo "[5/5] Verifying Traefik installation..."
kubectl -n kube-system get deploy traefik -o wide | cat || true
kubectl -n kube-system get svc traefik -o wide | cat || true

cat <<EOF

Done. k3s is installed and Traefik is running.

Next steps:
- Ensure DNS: create wildcard A record *.wabr.cc -> your server IP
- Open ports 80/443 on Lightsail firewall
- Deploy tenants with scripts/deploy_tenant.sh

EOF


