#!/usr/bin/env bash
# ============================================================
# POST TERRAFORM APPLY RUNBOOK
# Run these steps in order every time you do terraform apply
# from scratch. Takes ~45 mins total (mostly waiting on AWS).
# Run as: bash docs/rebuild-runbook.sh
# ============================================================
set -euo pipefail

cd ~/courses/pokeshop

# ── STEP 1: Terraform apply ──────────────────────────────────
cd infrastructure
terraform apply -auto-approve
cd ~/courses/pokeshop

# ── STEP 2: Connect kubectl to new cluster ───────────────────
aws eks update-kubeconfig --region us-east-2 --name pokeshop

# Wait up to 10 minutes for nodes to be Ready — exits as soon as they are
kubectl wait --for=condition=Ready nodes --all --timeout=600s
kubectl get nodes

# ── STEP 3: Configure aws-auth (node + bastion access) ───────
kubectl apply -f - << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: arn:aws:iam::704225640908:role/pokeshop-eks-node-role
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
    - rolearn: arn:aws:iam::704225640908:role/pokeshop-bastion-role
      username: bastion
      groups:
        - system:masters
EOF

# ── STEP 4: Configure bastion with Ansible ───────────────────
BASTION_IP=$(cd infrastructure && terraform output -raw bastion_ip)

# Update hosts.ini with the new bastion IP
sed -i "s/[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+/$BASTION_IP/" ansible/inventory/hosts.ini

# Wait for bastion EC2 SSH to become available (checks every 5s, up to 3 minutes)
echo "Waiting for bastion SSH to be available..."
for i in $(seq 1 36); do
  if ssh -i ~/.ssh/pokeshop-bastion \
       -o ConnectTimeout=5 \
       -o StrictHostKeyChecking=no \
       ubuntu@${BASTION_IP} "exit" 2>/dev/null; then
    echo "Bastion SSH is ready ✓"
    break
  fi
  echo "  attempt $i/36 — retrying in 5s..."
  sleep 5
done

ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/setup-bastion.yml

# ── STEP 5: Push Docker images to ECR ────────────────────────
# Skip this step if code hasn't changed — ECR images survive terraform destroy
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
REGION=us-east-2
TAG=$(git rev-parse --short HEAD)
REGISTRY="${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com"

aws ecr get-login-password --region $REGION | \
  docker login --username AWS --password-stdin $REGISTRY

for SERVICE in auth-service pokemon-service favorites-service; do
  echo "Building pokeshop-${SERVICE}..."
  docker build -t pokeshop-${SERVICE}:${TAG} ./services/${SERVICE}
  docker tag pokeshop-${SERVICE}:${TAG} ${REGISTRY}/pokeshop-${SERVICE}:${TAG}
  docker tag pokeshop-${SERVICE}:${TAG} ${REGISTRY}/pokeshop-${SERVICE}:latest
  docker push ${REGISTRY}/pokeshop-${SERVICE}:${TAG}
  docker push ${REGISTRY}/pokeshop-${SERVICE}:latest
done

docker build \
  --build-arg VITE_AUTH_URL=https://api.devopswithdev.com \
  --build-arg VITE_POKEMON_URL=https://api.devopswithdev.com \
  --build-arg VITE_FAVORITES_URL=https://api.devopswithdev.com \
  -t pokeshop-frontend:${TAG} ./frontend
docker tag pokeshop-frontend:${TAG} ${REGISTRY}/pokeshop-frontend:${TAG}
docker tag pokeshop-frontend:${TAG} ${REGISTRY}/pokeshop-frontend:latest
docker push ${REGISTRY}/pokeshop-frontend:${TAG}
docker push ${REGISTRY}/pokeshop-frontend:latest

# ── STEP 6: Seed databases from bastion ──────────────────────
# Bastion has VPC access to private RDS — your laptop does not
bash scripts/run-seed-from-laptop.sh
# Takes ~8 minutes total (dev + prod, 151 pokemon each)

# ── STEP 7: Install ArgoCD ───────────────────────────────────
# --dry-run=client -o yaml | kubectl apply makes this idempotent
# (won't error if namespace already exists)
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -n argocd -f \
  https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml || true
# The CRD annotation error is a known ArgoCD quirk — || true prevents it from
# stopping the script. ArgoCD still installs correctly despite the error.

# Wait up to 5 minutes for ArgoCD server to be ready
kubectl wait --for=condition=available deployment/argocd-server \
  -n argocd --timeout=300s

kubectl get pods -n argocd

# ── STEP 8: Enable apiKey capability on admin account ────────
# Must be done BEFORE generating the token
kubectl -n argocd patch configmap argocd-cm \
  --patch '{"data":{"accounts.admin":"apiKey,login"}}'

sleep 10

# ── STEP 9: Get ArgoCD password and log in ───────────────────
ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)

echo "Initial ArgoCD password: $ARGOCD_PASS"

# Start port-forward in background
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
sleep 5

argocd login localhost:8080 \
  --username admin \
  --password "$ARGOCD_PASS" \
  --insecure

# ── STEP 10: Change ArgoCD password ──────────────────────────
argocd account update-password \
  --current-password "$ARGOCD_PASS" \
  --new-password 'Pokemonmaster1!'

# ── STEP 11: Generate GitHub Actions token + update GitHub Secret ────────
ARGOCD_TOKEN=$(argocd account generate-token --account admin)

# Automatically update the GitHub Secret — no manual step needed
gh secret set ARGOCD_AUTH_TOKEN \
  --body "$ARGOCD_TOKEN" \
  --repo devshah95/PokeDex-Live

echo "ARGOCD_AUTH_TOKEN updated in GitHub Secrets ✓"

# ── STEP 12: Apply ArgoCD Application definitions ────────────
kubectl apply -f kubernetes/argocd/pokeshop-dev.yaml
kubectl apply -f kubernetes/argocd/pokeshop-prod.yaml

argocd app list
# STATUS and HEALTH will be blank — expected, manifests don't exist yet

echo ""
echo "=== Phase 17 complete ==="
echo "Next: Phase 18 — Gateway API"