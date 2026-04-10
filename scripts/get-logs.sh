#!/usr/bin/env bash
set -euo pipefail

SERVICE="${1:?Usage: $0 <service> [dev|prod]}"
ENV="${2:-dev}"
NS="pokeshop-${ENV}"

kubectl logs \
  -n ${NS} \
  -l app=${SERVICE} \
  --tail=100 \
  --follow
