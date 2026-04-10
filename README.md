# PokéDex Live — Full-Stack DevOps Mega Project

A cloud-native Pokémon browsing app built end-to-end as a complete DevOps showcase.
Users can browse all 151 original Pokémon, search by name or type, and save favorites.
The application is intentionally simple — the complexity is entirely in the infrastructure,
pipeline, and operations layer.

**Live URLs**
- App: https://devopswithdev.com
- API: https://api.devopswithdev.com
- ArgoCD: https://argocd.devopswithdev.com
- Grafana: https://grafana.devopswithdev.com

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Tech Stack](#tech-stack)
3. [Application Services](#application-services)
4. [Infrastructure](#infrastructure)
5. [Kubernetes & GitOps](#kubernetes--gitops)
6. [CI/CD Pipeline](#cicd-pipeline)
7. [Observability](#observability)
8. [Security](#security)
9. [Local Development Setup](#local-development-setup)
10. [AWS Infrastructure Setup](#aws-infrastructure-setup)
11. [Rebuilding the Cluster](#rebuilding-the-cluster)
12. [Useful Commands](#useful-commands)
13. [Cost Management](#cost-management)
14. [Project Structure](#project-structure)

---

## Architecture Overview

```
Internet
    │
    ▼
Route 53 (DNS — devopswithdev.com)
    │
    ▼
ACM Certificate (*.devopswithdev.com — TLS termination)
    │
    ▼
Application Load Balancer (Terraform-managed, public subnets)
    │
    ▼
AWS Gateway API Controller (Kubernetes — routes traffic by hostname + path)
    │
    ├── devopswithdev.com          → frontend (Nginx serving React)
    ├── api.devopswithdev.com/auth      → auth-service (port 3001)
    ├── api.devopswithdev.com/pokemon   → pokemon-service (port 3002)
    └── api.devopswithdev.com/favorites → favorites-service (port 3003)

EKS Cluster: pokeshop (us-east-2)
    ├── Namespace: pokeshop-dev
    │     ├── auth-service        (1 replica)
    │     ├── pokemon-service     (1 replica)
    │     ├── favorites-service   (1 replica)
    │     └── frontend            (1 replica)
    ├── Namespace: pokeshop-prod
    │     ├── auth-service        (2 replicas)
    │     ├── pokemon-service     (2-10 replicas, HPA on CPU 70%)
    │     ├── favorites-service   (2 replicas)
    │     └── frontend            (2 replicas)
    ├── Namespace: argocd         (GitOps CD controller)
    ├── Namespace: monitoring     (Prometheus + Grafana)
    └── Namespace: amazon-cloudwatch (Fluent Bit log shipper)

AWS Data Layer
    ├── RDS PostgreSQL × 6        (auth/pokemon/favorites × dev/prod)
    ├── ElastiCache Redis × 2     (dev/prod — pokemon service caching)
    └── MSK Kafka × 2             (dev/prod — favorites → pokemon events)
```

---

## Tech Stack

| Tool | Role in This Project |
|---|---|
| **Node.js / Express** | 3 backend microservices (auth, pokemon, favorites) |
| **React / Vite** | Frontend — Pokémon browsing UI with search and favorites |
| **PostgreSQL (RDS)** | Database per service — 3 services × 2 envs = 6 instances |
| **Redis (ElastiCache)** | Pokemon service caches PokéAPI responses — 1 hour TTL |
| **Kafka (MSK)** | Async event flow: favorites-service publishes `pokemon.favorited`, pokemon-service consumes it to increment favorite counts |
| **Docker** | Multi-stage Dockerfiles for all 4 services |
| **Kubernetes / EKS** | Container orchestration — dev and prod namespaces |
| **Terraform** | Provisions all AWS infrastructure as code |
| **Ansible** | Configures the bastion EC2 host |
| **GitHub Actions** | CI: test → OWASP → SonarQube → Trivy → build → push |
| **ArgoCD** | CD: GitOps — watches Git, syncs cluster when manifests change |
| **Kustomize** | Manages dev vs prod Kubernetes config differences |
| **SonarQube** | Code quality gate — blocks pipeline if quality drops |
| **OWASP** | Dependency scan — blocks pipeline if known CVE in npm packages |
| **Trivy** | Image scan — blocks pipeline if CRITICAL CVE in Docker image |
| **Prometheus** | Scrapes /metrics from all 3 backend services every 15 seconds |
| **Grafana** | Visualizes metrics — cache hit ratio, request rates, error rate, latency |
| **Fluent Bit** | DaemonSet log shipper — ships all container logs to CloudWatch |
| **Lambda** | Nightly PokéAPI sync at 2 AM UTC via EventBridge Scheduler |
| **AWS Gateway API** | Modern replacement for ingress-nginx (retired March 2026) |
| **Route 53 + ACM** | DNS and TLS certificates for devopswithdev.com |
| **Secrets Manager** | Stores all database credentials, JWT secret, Redis/Kafka endpoints |
| **IRSA** | IAM Roles for Service Accounts — pods authenticate to AWS without static keys |
| **ECR** | Private container registry — 4 repositories (one per service) |

---

## Application Services

### Auth Service (port 3001)
Handles user registration, login, and JWT issuance.

**Endpoints:**
- `POST /auth/register` — create account, returns JWT
- `POST /auth/login` — verify credentials, returns JWT
- `GET /auth/users/:id` — get user profile
- `GET /health` — Kubernetes liveness/readiness probe
- `GET /metrics` — Prometheus scrape endpoint

**Key design decisions:**
- Passwords hashed with bcrypt (12 salt rounds)
- JWT tokens expire after 24 hours
- PostgreSQL error code `23505` (unique violation) returns 409 instead of 500
- Same error message for "user not found" and "wrong password" — prevents user enumeration attacks

### Pokemon Service (port 3002)
Serves Pokémon data with Redis caching and Kafka event consumption.

**Endpoints:**
- `GET /pokemon` — paginated list with optional `?type=fire` filter
- `GET /pokemon/:id` — by pokedex number or name
- `GET /pokemon/random` — random Pokémon
- `GET /health` — probe
- `GET /metrics` — Prometheus (includes `pokemon_cache_hits_total` and `pokemon_cache_misses_total`)

**Key design decisions:**
- Redis cache TTL: 1 hour for individual Pokémon, 5 minutes for lists
- Cache miss → query PostgreSQL → store in Redis → return response
- If Redis is unavailable, service degrades gracefully (no crash, just slower)
- Kafka consumer listens for `pokemon.favorited` events and increments `favorite_count` on the relevant row
- Cache invalidated when a `pokemon.favorited` event is received so the next read gets fresh data

### Favorites Service (port 3003)
Saves user favorites and publishes Kafka events.

**Endpoints:**
- `GET /favorites` — get current user's favorites (requires JWT)
- `POST /favorites` — add a Pokémon to favorites (requires JWT)
- `DELETE /favorites/:pokedexId` — remove a favorite (requires JWT)
- `GET /health` — probe
- `GET /metrics` — Prometheus

**Key design decisions:**
- All routes require a valid JWT in the `Authorization: Bearer <token>` header
- Does NOT call pokemon-service directly — publishes `pokemon.favorited` to Kafka and returns immediately
- `UNIQUE(user_id, pokedex_id)` constraint prevents duplicate favorites, returns 409
- Kafka failures are logged but do not break the favorites save — resilient to Kafka being temporarily down

### Frontend (port 80)
React app served by Nginx.

**Key design decisions:**
- Multi-stage Dockerfile: Node.js builds the app, Nginx serves the static files — final image has no Node.js
- API URLs are baked in at Docker build time via `--build-arg VITE_*` flags — dev and prod have separate images
- Nginx config uses `try_files $uri $uri/ /index.html` so React Router works on page refresh
- `/health` endpoint returns 200 for Kubernetes probes

---

## Infrastructure

All AWS infrastructure is managed by Terraform. Nothing is created manually except:
- The S3 state bucket and DynamoDB lock table (chicken-and-egg problem)
- The SSH key pair for the bastion (`ssh-keygen -t ed25519 -f ~/.ssh/pokeshop-bastion`)

### Terraform Modules

```
infrastructure/
└── modules/
    ├── vpc/          VPC, public/private subnets, IGW, NAT Gateway, route tables
    ├── eks/          EKS cluster, node group (t3.medium × 2), OIDC provider for IRSA
    ├── rds/          RDS PostgreSQL, security group, subnet group, random password
    ├── elasticache/  ElastiCache Redis replication group, TLS enabled
    ├── msk/          MSK Kafka cluster, auto topic creation enabled
    ├── alb/          Application Load Balancer, HTTP→HTTPS redirect, HTTPS listener
    ├── route53/      ACM certificate, DNS validation records, A records for all subdomains
    ├── s3/           S3 bucket per environment for application assets
    ├── iam/          IRSA roles — dev pods can only read dev secrets, prod pods read prod
    └── secrets/      Secrets Manager secrets for all DB credentials, JWT, Redis, Kafka
```

### Key Terraform Design Decisions

**Why 6 RDS instances?**
3 services × 2 environments = 6. Each service owns its data independently.
Services cannot query each other's tables. This is the database-per-service pattern.

**Why IRSA instead of instance profiles?**
IRSA (IAM Roles for Service Accounts) gives each Kubernetes namespace its own IAM role.
Dev pods can only read `pokeshop/dev/*` secrets. Prod pods can only read `pokeshop/prod/*` secrets.
If a dev pod is compromised, the attacker cannot read production credentials.

**Why a bastion host?**
RDS, ElastiCache, and MSK are in private subnets — unreachable from the internet.
The bastion is an EC2 in the public subnet that has VPC access to all private resources.
Database migrations and seeding run from the bastion, not from your laptop.

---

## Kubernetes & GitOps

### Kustomize Structure

```
kubernetes/
├── base/                     Shared config for all environments
│   ├── auth/                 Deployment + Service + ServiceAccount
│   ├── pokemon/              Deployment + Service
│   ├── favorites/            Deployment + Service
│   ├── frontend/             Deployment + Service
│   ├── monitoring/           ServiceMonitor (Prometheus scrape config)
│   ├── gateway.yaml          GatewayClass + Gateway
│   ├── httproute-api.yaml    Routes for api.devopswithdev.com
│   └── httproute-frontend.yaml Routes for devopswithdev.com
├── overlays/
│   ├── dev/                  Dev-specific: 1 replica, debug logging, dev hostnames
│   └── prod/                 Prod-specific: 2 replicas, HPA, warning logging, prod hostnames
└── argocd/
    ├── pokeshop-dev.yaml     ArgoCD Application watching develop branch
    └── pokeshop-prod.yaml    ArgoCD Application watching main branch
```

### GitOps Flow (how a code change reaches production)

```
1. Developer pushes code to develop branch
2. GitHub Actions CI runs:
   a. Unit tests (Jest) for all 3 services in parallel
   b. OWASP dependency scan — fails if CVE score >= 7
   c. SonarQube analysis — fails if quality gate not met
   d. Docker build for each service
   e. Trivy image scan — fails if CRITICAL CVE found
   f. Push image to ECR with commit SHA tag
3. GitHub Actions CD (deploy-dev.yml) runs:
   a. Updates image tag in kubernetes/overlays/dev/kustomization.yaml
   b. Commits the tag update back to Git
4. ArgoCD detects the Git change (polls every 3 minutes)
5. ArgoCD applies the new kustomization to pokeshop-dev namespace
6. Kubernetes rolls out the new pods with zero downtime
7. Smoke test runs against dev-api.devopswithdev.com

For prod: same flow but push to main branch triggers a manual approval
gate in GitHub Environments before the deploy proceeds.
```

### Why ArgoCD instead of kubectl in the pipeline?

Without ArgoCD the pipeline would run `kubectl apply` directly — meaning the CI system
needs cluster credentials stored as secrets, and there is no audit trail of what changed when.

With ArgoCD, Git is the source of truth. The pipeline only updates a file in Git.
ArgoCD (running inside the cluster) detects the change and applies it.
The pipeline never touches `kubectl`. Rollback is `git revert`.

---

## CI/CD Pipeline

### CI Pipeline (`.github/workflows/ci.yml`)

Triggers on every push to `develop` or `main`, and on all pull requests.

```
Job 1: Unit Tests (parallel across all 3 services)
    └── npm ci → npm test --coverage → upload lcov report as artifact

Job 2: OWASP Dependency Check (needs: test)
    └── Scans package.json files for known CVEs
    └── Fails if CVSS score >= 7

Job 3: SonarQube Analysis (needs: test)
    └── Downloads coverage reports from Job 1
    └── Runs sonar-scanner against all service source code
    └── Checks quality gate — fails if threshold not met

Job 4: Build + Trivy + Push (needs: test, owasp, sonarqube)
    └── Runs only on push events (not PRs)
    └── Builds Docker image for each service
    └── Trivy scans the built image — fails on CRITICAL CVEs
    └── Pushes to ECR with commit SHA tag and latest tag

Job 5: Slack notification (always runs, reports pipeline status)
```

### CD Pipelines

**Dev** (`.github/workflows/deploy-dev.yml`):
- Triggers on push to `develop`
- Updates image tags in `kubernetes/overlays/dev/kustomization.yaml`
- Commits back to Git → ArgoCD syncs automatically
- Runs smoke test against dev endpoints

**Prod** (`.github/workflows/deploy-prod.yml`):
- Triggers on push to `main`
- Pauses at `environment: production` for manual approval
- After approval: updates prod overlay → ArgoCD syncs
- `selfHeal: false` on prod ArgoCD app — manual cluster changes are not auto-reverted

**Infra** (`.github/workflows/infra.yml`):
- Triggers on changes to `infrastructure/**`
- PRs: runs `terraform plan` and posts output as a PR comment
- Merge to main: runs `terraform apply` (requires production environment approval)

---

## Observability

### Prometheus + Grafana

Installed via Helm (`kube-prometheus-stack`) in the `monitoring` namespace.
Scrapes all pods with `prometheus.io/scrape: "true"` annotations every 15 seconds.

**Grafana dashboards** (`monitoring/dashboards/pokeshop.json`):

| Panel | PromQL | What it shows |
|---|---|---|
| Request Rate | `rate(http_requests_total[5m])` | Requests per second per service |
| Cache Hit Ratio | `rate(pokemon_cache_hits_total[5m]) / (hits + misses) * 100` | Redis effectiveness — target >80% |
| Error Rate | `rate(http_requests_total{status=~"5.."}[5m]) / total * 100` | 5xx errors as % of total |
| Pod Count | `kube_deployment_status_replicas_available` | Running replicas per deployment |
| P95 Latency | `histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))` | 95th percentile response time |

Access Grafana: `kubectl port-forward svc/monitoring-grafana 3100:80 -n monitoring`
Login: `admin / PokeDexLiveGrafana2026`

### CloudWatch Logging

Fluent Bit runs as a DaemonSet (one pod per node) and ships all container logs to CloudWatch.
Log group: `/pokeshop`

**Useful Log Insights queries** (see `monitoring/cloudwatch-queries.md`):

```
# All errors across both namespaces
fields @timestamp, @message, kubernetes.namespace_name, kubernetes.container_name
| filter kubernetes.namespace_name in ["pokeshop-dev", "pokeshop-prod"]
| filter @message like /ERROR|error|Error/
| sort @timestamp desc
| limit 100
```

### Lambda Nightly Sync

`lambda/pokemon-sync/handler.py` runs every night at 2 AM UTC via EventBridge Scheduler.
Fetches all 151 Pokémon from PokéAPI and upserts them into both dev and prod databases.
Uses Secrets Manager for database credentials — no hardcoded values.

---

## Security

### What is secured and how

| Control | Implementation |
|---|---|
| No static AWS keys | GitHub Actions uses OIDC — short-lived tokens only |
| Namespace isolation | Dev pods can only read `pokeshop/dev/*` secrets via IRSA |
| Private databases | RDS, Redis, Kafka are in private subnets — no public access |
| TLS everywhere | ACM certificate covers `*.devopswithdev.com`, HTTP redirects to HTTPS |
| Image scanning | Trivy blocks deploys if CRITICAL CVEs found in Docker images |
| Dependency scanning | OWASP blocks deploys if known CVE in npm packages |
| Code quality gate | SonarQube blocks deploys if new vulnerabilities introduced |
| Non-root containers | All backend containers run as `appuser` not root |
| Secret rotation | All DB passwords generated by Terraform `random_password` — never hardcoded |
| ECR scan on push | Every pushed image automatically scanned for CVEs |

Run `bash scripts/security-check.sh` to verify all controls are active.

---

## Local Development Setup

**Prerequisites:** Docker Desktop, Node.js 20, Git, jq

```bash
# 1. Clone the repo
git clone https://github.com/devshah95/PokeDex-Live.git
cd PokeDex-Live

# 2. Start the full stack (PostgreSQL × 3, Redis, Kafka, all services, frontend)
docker-compose up --build -d

# 3. Run database migrations
docker-compose exec auth-service node src/db/migrate.js
docker-compose exec pokemon-service node src/db/migrate.js
docker-compose exec favorites-service node src/db/migrate.js

# 4. Seed Pokémon data (fetches 151 Pokémon from PokéAPI — takes ~3 minutes)
docker-compose exec pokemon-service node src/db/seed.js

# 5. Open the app
open http://localhost:3000
```

**Local service URLs:**
- Frontend: http://localhost:3000
- Auth Service: http://localhost:3001
- Pokemon Service: http://localhost:3002
- Favorites Service: http://localhost:3003
- Grafana: http://localhost:3100 (admin/admin)
- Prometheus: http://localhost:9090
- SonarQube: http://localhost:9000 (admin/admin)

**Run all unit tests:**
```bash
for svc in auth-service pokemon-service favorites-service; do
  echo "=== Testing $svc ==="
  (cd services/$svc && npm test)
done
```

---

## AWS Infrastructure Setup

**One-time prerequisites (done once, never again):**

```bash
# 1. Create SSH key for bastion
ssh-keygen -t ed25519 -f ~/.ssh/pokeshop-bastion -N ""

# 2. Create Terraform state bucket (replace with your account ID)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws s3api create-bucket \
  --bucket "pokeshop-tfstate-${ACCOUNT_ID}" \
  --region us-east-2 \
  --create-bucket-configuration LocationConstraint=us-east-2
aws s3api put-bucket-versioning \
  --bucket "pokeshop-tfstate-${ACCOUNT_ID}" \
  --versioning-configuration Status=Enabled

# 3. Create DynamoDB lock table
aws dynamodb create-table \
  --table-name pokeshop-tf-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-2

# 4. Register GitHub as OIDC provider
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

# 5. Create ECR repositories
for SERVICE in auth-service pokemon-service favorites-service frontend; do
  aws ecr create-repository \
    --repository-name pokeshop-${SERVICE} \
    --region us-east-2 \
    --image-scanning-configuration scanOnPush=true
done
```

---

## Rebuilding the Cluster

When you run `terraform destroy` and need to rebuild everything from scratch:

```bash
cd ~/courses/pokeshop
bash docs/rebuild-runbook.sh
```

This single script handles everything automatically:
- `terraform apply` (30-45 minutes)
- Connect kubectl to the new cluster
- Configure aws-auth for node and bastion access
- Run Ansible to configure the bastion
- Push Docker images to ECR
- Seed all 6 databases (dev + prod, 151 Pokémon each)
- Install ArgoCD
- Configure ArgoCD and update GitHub Secrets automatically
- Apply ArgoCD Application definitions
- Apply Gateway API resources
- Install Prometheus + Grafana
- Install Fluent Bit → CloudWatch

The only manual step after the script finishes is going to GitHub Settings → Environments → production and verifying the required reviewer is still set.

---

## Useful Commands

**Cluster access:**
```bash
# Connect kubectl to EKS
aws eks update-kubeconfig --region us-east-2 --name pokeshop

# Get all pods across all namespaces
kubectl get pods -A

# Watch pods in dev namespace
kubectl get pods -n pokeshop-dev -w

# Get all resources in dev namespace
kubectl get all -n pokeshop-dev
```

**Logs:**
```bash
# Tail logs from a service
bash scripts/get-logs.sh auth-service dev
bash scripts/get-logs.sh pokemon-service prod

# Get recent logs without following
kubectl logs -n pokeshop-dev -l app=auth-service --tail=50
```

**ArgoCD:**
```bash
# Port-forward ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

# List all applications
argocd app list

# Force sync dev
argocd app sync pokeshop-dev

# Check app health
argocd app get pokeshop-dev
```

**Port-forward all tools at once:**
```bash
bash scripts/port-forward.sh
# ArgoCD  → https://localhost:8080
# Grafana → http://localhost:3100
# Prometheus → http://localhost:9090
```

**Rollback:**
```bash
# Roll back all deployments in dev to previous version
bash scripts/rollback.sh dev

# Roll back prod
bash scripts/rollback.sh prod
```

**Health checks:**
```bash
bash scripts/health-check.sh dev
bash scripts/health-check.sh prod
```

**Security audit:**
```bash
bash scripts/security-check.sh
```

**Database access (via bastion):**
```bash
BASTION_IP=$(cd infrastructure && terraform output -raw bastion_ip)
ssh -i ~/.ssh/pokeshop-bastion ubuntu@${BASTION_IP}

# On bastion — connect to dev auth DB
SECRET=$(aws secretsmanager get-secret-value \
  --secret-id pokeshop/dev/auth-db --query SecretString --output text)
PGPASSWORD=$(echo $SECRET | jq -r '.password') \
  psql -h $(echo $SECRET | jq -r '.host' | cut -d: -f1) \
       -U $(echo $SECRET | jq -r '.username') \
       -d $(echo $SECRET | jq -r '.dbname')
```

---

## Cost Management

This stack costs approximately **$25-35/day** when running. Always destroy when not working.

```bash
# Destroy all infrastructure (takes ~20 minutes)
cd infrastructure
terraform destroy -auto-approve

# Rebuild when ready to work again
cd ..
bash docs/rebuild-runbook.sh
```

**What survives destroy (no charges when destroyed):**
- S3 state bucket — negligible cost, never delete
- DynamoDB lock table — negligible cost, never delete
- ECR images — no cost when not running, images reused on next apply
- Route 53 hosted zone — ~$0.50/month, keep it

**What gets destroyed and recreated:**
- EKS cluster + nodes (~$5/day)
- RDS instances × 6 (~$8/day)
- ElastiCache Redis × 2 (~$3/day)
- MSK Kafka × 2 (~$10/day)
- NAT Gateway (~$4/day)
- ALB (~$2/day)

---

## Project Structure

```
pokeshop/
├── .github/
│   └── workflows/
│       ├── ci.yml              CI: test → OWASP → SonarQube → Trivy → build → push
│       ├── deploy-dev.yml      CD: update dev image tags → ArgoCD syncs
│       ├── deploy-prod.yml     CD: manual approval → update prod tags → ArgoCD syncs
│       └── infra.yml           Terraform plan on PR, apply on merge to main
├── ansible/
│   ├── inventory/hosts.ini     Bastion host IP
│   └── playbooks/
│       └── setup-bastion.yml   Installs kubectl, helm, argocd CLI, AWS CLI, psql
├── docs/
│   └── rebuild-runbook.sh      Full automated rebuild from terraform apply to Phase 27
├── frontend/
│   ├── src/
│   │   ├── pages/              Pokedex.jsx, Login.jsx, Register.jsx
│   │   └── services/api.js     All API calls — reads VITE_* env vars baked in at build
│   ├── Dockerfile              Multi-stage: Node builds → Nginx serves
│   └── nginx.conf              try_files for React Router + /health endpoint
├── infrastructure/
│   ├── main.tf                 Root module — wires all modules together
│   └── modules/
│       ├── vpc/                VPC, subnets, IGW, NAT, route tables
│       ├── eks/                EKS cluster + node group + OIDC provider
│       ├── rds/                PostgreSQL per service per env
│       ├── elasticache/        Redis per env
│       ├── msk/                Kafka per env
│       ├── alb/                Application Load Balancer
│       ├── route53/            ACM cert + DNS records
│       ├── s3/                 Asset buckets
│       ├── iam/                IRSA roles per env
│       └── secrets/            Secrets Manager secrets
├── kubernetes/
│   ├── argocd/                 ArgoCD Application definitions
│   ├── base/                   Shared manifests (deployments, services, httproutes)
│   └── overlays/
│       ├── dev/                1 replica, debug logging, dev hostnames
│       └── prod/               2 replicas, HPA, warning logging, prod hostnames
├── lambda/
│   └── pokemon-sync/
│       ├── handler.py          Nightly sync — PokéAPI → RDS dev + prod
│       └── requirements.txt    psycopg2, boto3
├── monitoring/
│   ├── dashboards/pokeshop.json  Grafana dashboard JSON
│   ├── prometheus-local.yml    Local Prometheus scrape config
│   └── cloudwatch-queries.md   Useful Log Insights queries
├── scripts/
│   ├── deploy-phase21.sh       Creates K8s Secrets from Secrets Manager + first deploy
│   ├── get-logs.sh             Tail logs from any service
│   ├── health-check.sh         Smoke test — checks all 3 /health endpoints
│   ├── migrations/             SQL DDL files for all 3 services
│   ├── port-forward.sh         Port-forwards ArgoCD + Grafana + Prometheus
│   ├── push-images.sh          Build and push all 4 images to ECR
│   ├── rollback.sh             kubectl rollout undo for all deployments
│   ├── run-seed-from-laptop.sh Copies seed scripts to bastion and runs them
│   ├── security-check.sh       Verifies all security controls are active
│   ├── seed-databases.sh       Runs on bastion — migrates and seeds all 6 DBs
│   └── setup-monitoring.sh     Installs Prometheus + Grafana via Helm
├── services/
│   ├── auth-service/           Express + pg + bcrypt + jwt + prom-client
│   ├── pokemon-service/        Express + pg + redis + kafkajs + prom-client
│   └── favorites-service/      Express + pg + kafkajs + jwt + prom-client
└── docker-compose.yaml         Full local stack — all services + DBs + Redis + Kafka
