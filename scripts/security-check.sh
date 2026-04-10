#!/usr/bin/env bash
# Phase 30 — Security hardening checklist
# Run this to verify all security controls are in place
# Usage: bash scripts/security-check.sh

set -euo pipefail

PASS=0
FAIL=0

log_pass() { echo "  ✓ $*"; PASS=$((PASS + 1)); }
log_fail() { echo "  ✗ $*"; FAIL=$((FAIL + 1)); }
section() { echo ""; echo "── $* ──────────────────────────────────────"; }

# ── Secrets ───────────────────────────────────────────────────────────────
section "Secrets"

# Check no .env files were ever committed
if git log --all -- "**/.env" | grep -q commit; then
  log_fail ".env files found in git history"
else
  log_pass "No .env files in git history"
fi

# Check no AWS keys were ever committed
if git log --all -S "AKIA" --oneline | grep -q .; then
  log_fail "AWS access keys found in git history"
else
  log_pass "No AWS access keys in git history"
fi

# ── Network ───────────────────────────────────────────────────────────────
section "Network"

# Verify RDS instances are not publicly accessible
PUBLIC_RDS=$(aws rds describe-db-instances \
  --query 'DBInstances[?PubliclyAccessible==`true`].DBInstanceIdentifier' \
  --output text)
if [ -z "$PUBLIC_RDS" ]; then
  log_pass "All RDS instances are private"
else
  log_fail "Public RDS instances found: $PUBLIC_RDS"
fi

# Verify HTTP redirects to HTTPS
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://devopswithdev.com || true)
if [ "$HTTP_STATUS" = "301" ] || [ "$HTTP_STATUS" = "302" ]; then
  log_pass "HTTP redirects to HTTPS (${HTTP_STATUS})"
else
  log_fail "HTTP does not redirect to HTTPS (got ${HTTP_STATUS})"
fi

# ── Kubernetes ────────────────────────────────────────────────────────────
section "Kubernetes"

# Verify IRSA is working on dev pod
ROLE_ARN=$(kubectl exec -n pokeshop-dev \
  $(kubectl get pod -n pokeshop-dev -l app=auth-service -o name | head -1) \
  -- printenv AWS_ROLE_ARN 2>/dev/null || true)
if [ -n "$ROLE_ARN" ]; then
  log_pass "IRSA working on dev pod (role: $ROLE_ARN)"
else
  log_fail "IRSA not configured on dev pods"
fi

# Verify dev pods cannot read prod secrets
ACCESS=$(kubectl exec -n pokeshop-dev \
  $(kubectl get pod -n pokeshop-dev -l app=auth-service -o name | head -1) \
  -- aws secretsmanager get-secret-value \
  --secret-id pokeshop/prod/jwt-secret 2>&1 || true)
if echo "$ACCESS" | grep -qi "access denied\|not authorized"; then
  log_pass "Dev pods cannot read prod secrets"
else
  log_fail "Dev pods CAN read prod secrets — fix IRSA policy"
fi

# Verify containers are not running as root
ROOT_CONTAINERS=$(kubectl get pods -n pokeshop-dev \
  -o jsonpath='{.items[*].spec.containers[*].securityContext.runAsNonRoot}' 2>/dev/null || true)
if echo "$ROOT_CONTAINERS" | grep -q "true"; then
  log_pass "Containers running as non-root"
else
  log_fail "Container security context not set — consider adding runAsNonRoot: true"
fi

# ── ECR ───────────────────────────────────────────────────────────────────
section "ECR"

# Verify scan on push is enabled
for REPO in auth-service pokemon-service favorites-service frontend; do
  SCAN=$(aws ecr describe-repositories \
    --repository-names pokeshop-${REPO} \
    --query 'repositories[0].imageScanningConfiguration.scanOnPush' \
    --output text 2>/dev/null || echo "false")
  if [ "$SCAN" = "True" ] || [ "$SCAN" = "true" ]; then
    log_pass "ECR scan-on-push enabled: pokeshop-${REPO}"
  else
    log_fail "ECR scan-on-push disabled: pokeshop-${REPO}"
  fi
done

# ── S3 ────────────────────────────────────────────────────────────────────
section "S3"

# Verify state bucket blocks public access
BUCKET="pokeshop-tfstate-$(aws sts get-caller-identity --query Account --output text)"
PUBLIC_ACCESS=$(aws s3api get-bucket-public-access-block \
  --bucket "$BUCKET" \
  --query 'PublicAccessBlockConfiguration.BlockPublicAcls' \
  --output text 2>/dev/null || echo "false")
if [ "$PUBLIC_ACCESS" = "True" ] || [ "$PUBLIC_ACCESS" = "true" ]; then
  log_pass "Terraform state bucket blocks public access"
else
  log_fail "Terraform state bucket public access not fully blocked"
fi

# ── Summary ───────────────────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════"
echo "  Security check complete"
echo "  Passed: $PASS"
echo "  Failed: $FAIL"
echo "════════════════════════════════════════"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
