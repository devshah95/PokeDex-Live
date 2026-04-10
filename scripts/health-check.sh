#!/usr/bin/env bash
set -euo pipefail

ENV="${1:-dev}"
BASE_URL="https://dev-api.devopswithdev.com"
if [ "$ENV" = "prod" ]; then
  BASE_URL="https://api.devopswithdev.com"
fi

log() { echo "[$(date +%H:%M:%S)] $*"; }

check() {
  local name=$1
  local url=$2
  local status
  status=$(curl -s -o /dev/null -w "%{http_code}" "$url")
  if [ "$status" = "200" ]; then
    log "  ✓ $name — HTTP $status"
  else
    log "  ✗ $name — HTTP $status (FAILED)"
    exit 1
  fi
}

log "Running health checks for env: ${ENV}"
check "Auth Service"      "${BASE_URL}/auth/health"
check "Pokemon Service"   "${BASE_URL}/pokemon/health"
check "Favorites Service" "${BASE_URL}/favorites/health"
log "All health checks passed ✓"
