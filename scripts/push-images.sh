#!/usr/bin/env bash
set -euo pipefail

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

echo "All images pushed successfully ✓"
