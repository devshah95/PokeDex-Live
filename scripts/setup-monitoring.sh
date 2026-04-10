#!/usr/bin/env bash
# Phase 26 — Install Prometheus + Grafana via Helm
# Add this to the runbook — must be run after every terraform apply
set -euo pipefail

helm repo add prometheus-community \
  https://prometheus-community.github.io/helm-charts
helm repo update

# Install the full kube-prometheus-stack
# Includes: Prometheus + Grafana + Alertmanager + node exporters + kube-state-metrics
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set grafana.adminPassword="PokeDexLiveGrafana2026" \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues=false

# serviceMonitorSelectorNilUsesHelmValues=false means Prometheus discovers ALL
# ServiceMonitors in the cluster, not just those from this Helm release

kubectl wait --for=condition=available deployment/monitoring-grafana \
  -n monitoring --timeout=300s

kubectl get pods -n monitoring

# Apply the ServiceMonitor so Prometheus scrapes our app pods
kubectl apply -f kubernetes/base/monitoring/servicemonitor.yaml

echo "Monitoring stack installed ✓"
echo ""
echo "To access Grafana locally:"
echo "  kubectl port-forward svc/monitoring-grafana 3100:80 -n monitoring"
echo "  http://localhost:3100 — admin / PokeDexLiveGrafana2026"
