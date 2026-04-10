#!/usr/bin/env bash
set -euo pipefail
cd ~/courses/pokeshop

for ENV in dev prod; do
  NS="pokeshop-${ENV}"
  echo "Setting up namespace: $NS"

  kubectl create namespace $NS --dry-run=client -o yaml | kubectl apply -f -

  SECRET=$(aws secretsmanager get-secret-value \
    --secret-id "pokeshop/${ENV}/auth-db" \
    --query SecretString --output text)
  kubectl create secret generic auth-secrets \
    --from-literal=db_host=$(echo $SECRET | jq -r '.host' | cut -d: -f1) \
    --from-literal=db_user=$(echo $SECRET | jq -r '.username') \
    --from-literal=db_password=$(echo $SECRET | jq -r '.password') \
    --from-literal=db_name=$(echo $SECRET | jq -r '.dbname') \
    --namespace $NS --dry-run=client -o yaml | kubectl apply -f -

  SECRET=$(aws secretsmanager get-secret-value \
    --secret-id "pokeshop/${ENV}/pokemon-db" \
    --query SecretString --output text)
  kubectl create secret generic pokemon-secrets \
    --from-literal=db_host=$(echo $SECRET | jq -r '.host' | cut -d: -f1) \
    --from-literal=db_user=$(echo $SECRET | jq -r '.username') \
    --from-literal=db_password=$(echo $SECRET | jq -r '.password') \
    --from-literal=db_name=$(echo $SECRET | jq -r '.dbname') \
    --namespace $NS --dry-run=client -o yaml | kubectl apply -f -

  SECRET=$(aws secretsmanager get-secret-value \
    --secret-id "pokeshop/${ENV}/favorites-db" \
    --query SecretString --output text)
  kubectl create secret generic favorites-secrets \
    --from-literal=db_host=$(echo $SECRET | jq -r '.host' | cut -d: -f1) \
    --from-literal=db_user=$(echo $SECRET | jq -r '.username') \
    --from-literal=db_password=$(echo $SECRET | jq -r '.password') \
    --from-literal=db_name=$(echo $SECRET | jq -r '.dbname') \
    --namespace $NS --dry-run=client -o yaml | kubectl apply -f -

  JWT_SECRET=$(aws secretsmanager get-secret-value \
    --secret-id "pokeshop/${ENV}/jwt-secret" \
    --query SecretString --output text | jq -r '.secret')
  REDIS_HOST=$(aws secretsmanager get-secret-value \
    --secret-id "pokeshop/${ENV}/redis" \
    --query SecretString --output text | jq -r '.host')
  KAFKA_BROKERS=$(aws secretsmanager get-secret-value \
    --secret-id "pokeshop/${ENV}/kafka" \
    --query SecretString --output text | jq -r '.brokers')

  kubectl create secret generic shared-secrets \
    --from-literal=jwt_secret="$JWT_SECRET" \
    --from-literal=redis_host="$REDIS_HOST" \
    --from-literal=kafka_brokers="$KAFKA_BROKERS" \
    --namespace $NS --dry-run=client -o yaml | kubectl apply -f -

  echo "Secrets created for $NS ✓"
done

kubectl apply -k kubernetes/overlays/dev/
echo "Dev overlay applied ✓"
kubectl get pods -n pokeshop-dev -w
