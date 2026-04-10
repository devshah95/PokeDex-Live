#!/usr/bin/env bash
# Usage: bash scripts/port-forward.sh
# Opens port-forwards for ArgoCD, Grafana, and Prometheus simultaneously

set -euo pipefail

echo "Starting port-forwards..."
echo "  ArgoCD  → https://localhost:8080"
echo "  Grafana → http://localhost:3100  (admin / PokeDexLiveGrafana2026)"
echo "  Prometheus → http://localhost:9090"
echo ""
echo "Press Ctrl+C to stop all"

# Run all in background
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
kubectl port-forward svc/monitoring-grafana -n monitoring 3100:80 &
kubectl port-forward svc/monitoring-kube-prometheus-stack-prometheus -n monitoring 9090:9090 &

# Wait — keeps script running until Ctrl+C
wait
