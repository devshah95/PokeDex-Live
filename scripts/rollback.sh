#!/usr/bin/env bash
set -euo pipefail

ENV="${1:-dev}"
NS="pokeshop-${ENV}"

log() { echo "[$(date +%H:%M:%S)] $*"; }
log "Rolling back all deployments in namespace: $NS"

for DEPLOY in auth-service pokemon-service favorites-service frontend; do
  kubectl rollout undo deployment/${DEPLOY} -n ${NS}
  kubectl rollout status deployment/${DEPLOY} -n ${NS} --timeout=120s
  log "  ✓ $DEPLOY rolled back"
done

log "Rollback complete ✓"
