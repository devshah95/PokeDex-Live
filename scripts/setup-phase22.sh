#!/usr/bin/env bash
# Phase 22 — GitHub repository secrets, environments, branch protection
# Run from: ~/courses/pokeshop
# Prerequisites: gh CLI authenticated (already done in Phase 17 setup)

set -euo pipefail
cd ~/courses/pokeshop

REPO="devshah95/PokeDex-Live"
ACCOUNT_ID="704225640908"
REGION="us-east-2"

# ── STEP 1: Get values needed for secrets ────────────────────────────────
ACTIONS_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/pokeshop-github-actions"

# Get ArgoCD server hostname — using localhost since we expose via port-forward
# In Phase 25 this will be updated to the real ArgoCD domain once it's exposed
ARGOCD_SERVER="localhost:8080"

echo "Setting GitHub Actions secrets..."

# ── STEP 2: Set all GitHub Actions secrets ───────────────────────────────
gh secret set ACTIONS_ROLE_ARN \
  --body "$ACTIONS_ROLE_ARN" \
  --repo $REPO

gh secret set AWS_ACCOUNT_ID \
  --body "$ACCOUNT_ID" \
  --repo $REPO

gh secret set EKS_CLUSTER_NAME \
  --body "pokeshop" \
  --repo $REPO

gh secret set ARGOCD_SERVER \
  --body "$ARGOCD_SERVER" \
  --repo $REPO

# ARGOCD_AUTH_TOKEN is already set by the rebuild runbook
# SONAR_TOKEN and SONAR_HOST_URL get added manually after SonarQube is set up in Phase 23
# SLACK_WEBHOOK_URL is optional — skip for now

echo "GitHub secrets set ✓"
gh secret list --repo $REPO

# ── STEP 3: Create GitHub Environments ───────────────────────────────────
echo "Creating GitHub environments..."

gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  /repos/${REPO}/environments/development

gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  /repos/${REPO}/environments/production \
  --field "prevent_self_review=false" \
  --field "reviewers=[]"

echo "Environments created ✓"

# ── STEP 4: Create develop branch if it doesn't exist ────────────────────
echo "Setting up develop branch..."

# Check if develop branch exists
if git ls-remote --heads origin develop | grep -q develop; then
  echo "develop branch already exists ✓"
else
  git checkout -b develop
  git push -u origin develop
  git checkout main
  echo "develop branch created ✓"
fi

echo ""
echo "=== Phase 22 complete ==="
echo ""
echo "Manual steps still needed in GitHub UI:"
echo "  1. Settings → Branches → Add rule for 'main':"
echo "     ✓ Require pull request reviews before merging"
echo "     ✓ Require status checks to pass"
echo "     ✓ Require branches to be up to date"
echo "  2. Settings → Branches → Add rule for 'develop':"
echo "     ✓ Require status checks to pass"
echo "  3. Settings → Environments → production:"
echo "     ✓ Add yourself as a Required Reviewer"
echo "     (This creates the manual approval gate before prod deploys)"
echo ""
echo "Next: Phase 23 — SonarQube setup"