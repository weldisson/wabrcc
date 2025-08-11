Infra: k3s + Traefik multi-tenant for wabr.cc

Overview
- Single-node Kubernetes with k3s on your Lightsail server
- Traefik (bundled with k3s) as Ingress Controller
- One Kubernetes Deployment/Service/Ingress per tenant subdomain (e.g., weldisson.wabr.cc)
- Each tenant uses the same container image but separate DATABASE_URL

Prerequisites
- DNS: point a wildcard A record to your server IP 54.237.179.146
  - Host: *.wabr.cc
  - Type: A
  - Value: 54.237.179.146
- Open inbound ports 80 and 443 on the Lightsail firewall

Install Docker (if needed) and k3s (run on the server)
```bash
sudo bash ./scripts/install_docker.sh
sudo bash ./scripts/install_k3s.sh
```

Configure database URL base
- The deploy script expects an environment variable `DATABASE_URL_PREFIX` like:
  - postgresql://postgres:YOUR_PASSWORD@your-rds-host:5432/
- The script will append the tenant name to build the final `DATABASE_URL`.

Deploy a tenant (run on the server)
```bash
# Example: weldisson.wabr.cc
export DATABASE_URL_PREFIX="postgresql://postgres:xxx@free-database.cukfpauavjwz.us-east-1.rds.amazonaws.com:5432/"
./scripts/deploy_tenant.sh weldisson 2 wabr.cc

# Example: drjoao.wabr.cc
./scripts/deploy_tenant.sh drjoao 2 wabr.cc
```

Create database per tenant (optional)
```bash
export DATABASE_ADMIN_URL="postgresql://postgres:xxx@free-database.cukfpauavjwz.us-east-1.rds.amazonaws.com:5432/postgres"
./scripts/create_tenant_db.sh weldisson
./scripts/create_tenant_db.sh drjoao
```

Delete a tenant
```bash
./scripts/delete_tenant.sh weldisson
```

Git submodule (healthProfessionalSite)
```bash
# Initialize submodule if fresh clone
git submodule update --init --recursive

# Pull latest from submodule main
git -C healthProfessionalSite pull origin main

# Switch submodule revision (optional)
git -C healthProfessionalSite checkout <branch|tag|commit>
git add healthProfessionalSite && git commit -m "chore: bump submodule"
```

Script arguments
- deploy_tenant.sh TENANT [REPLICAS] [DOMAIN_BASE]
  - TENANT: subdomain prefix (e.g., weldisson)
  - REPLICAS: number of pod replicas (default: 2)
  - DOMAIN_BASE: base domain (default: wabr.cc)

What the deploy script does
1. Builds the Docker image from `healthProfessionalSite/`
2. Imports the image into k3s' containerd
3. Renders Kubernetes manifests with envsubst
4. Applies Namespace/Deployment/Service/Ingress for the tenant

Result
- Access each tenant at: https://TENANT.wabr.cc (or http if TLS not configured)

Notes
- Traefik is enabled by default in k3s; we use standard Kubernetes Ingress
- For TLS/HTTPS automation, integrate cert-manager + Let’s Encrypt later
- To update a tenant after code changes: rerun the same `deploy_tenant.sh TENANT` (it will rebuild and roll pods)

Troubleshooting
- If image not found by k3s: ensure the script step "Importing image into k3s containerd" ran successfully.
- If Ingress not routing: check DNS and `kubectl -n kube-system get svc traefik` external IP/ports.
- App health: `kubectl -n tenant-<tenant> logs -l app.kubernetes.io/name=<tenant>-app -f`


