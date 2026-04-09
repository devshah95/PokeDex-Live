#!/usr/bin/env bash
# Run this from your laptop (~/courses/pokeshop) to deploy seed scripts to
# the bastion and execute them. The bastion needs VPC access to reach RDS.
set -euo pipefail

cd ~/courses/pokeshop
BASTION_IP=$(cd infrastructure && terraform output -raw bastion_ip)
KEY=~/.ssh/pokeshop-bastion

echo "Bastion IP: ${BASTION_IP}"

# Copy the SQL migration files first — seed-databases.sh expects them in /tmp/
scp -i "$KEY" scripts/migrations/migrate-auth.sql     ubuntu@${BASTION_IP}:/tmp/
scp -i "$KEY" scripts/migrations/migrate-pokemon.sql  ubuntu@${BASTION_IP}:/tmp/
scp -i "$KEY" scripts/migrations/migrate-favorites.sql ubuntu@${BASTION_IP}:/tmp/

# Copy the seed script itself
scp -i "$KEY" scripts/seed-databases.sh ubuntu@${BASTION_IP}:/tmp/

echo "Files copied. Running dev seed..."
ssh -i "$KEY" ubuntu@${BASTION_IP} "bash /tmp/seed-databases.sh dev"

echo "Running prod seed..."
ssh -i "$KEY" ubuntu@${BASTION_IP} "bash /tmp/seed-databases.sh prod"

echo "Done ✓"
