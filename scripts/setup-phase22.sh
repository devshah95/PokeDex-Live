#!/usr/bin/env bash
set -euo pipefail
cd ~/courses/pokeshop

REPO="devshah95/PokeDex-Live"
ACCOUNT_ID="704225640908"

gh secret set ACTIONS_ROLE_ARN \
  --body "arn:aws:iam::${ACCOUNT_ID}:role/pokeshop-github-actions" \
  --repo $REPO

gh secret set AWS_ACCOUNT_ID \
  --body "$ACCOUNT_ID" \
  --repo $REPO

gh secret set EKS_CLUSTER_NAME \
  --body "pokeshop" \
  --repo $REPO

gh secret set ARGOCD_SERVER \
  --body "argocd.devopswithdev.com" \
  --repo $REPO

echo "GitHub secrets set ✓"
gh secret list --repo $REPO

# Create environments
gh api --method PUT -H "Accept: application/vnd.github+json" \
  /repos/${REPO}/environments/development

gh api --method PUT -H "Accept: application/vnd.github+json" \
  /repos/${REPO}/environments/production

# Create develop branch if it doesn't exist
if git ls-remote --heads origin develop | grep -q develop; then
  echo "develop branch already exists ✓"
else
  git checkout -b develop
  git push -u origin develop
  git checkout main
  echo "develop branch created ✓"
fi

echo "Phase 22 complete ✓"
echo "Manual steps still needed in GitHub UI:"
echo "  1. Settings → Branches → protect main and develop"
echo "  2. Settings → Environments → production → add yourself as Required Reviewer"
