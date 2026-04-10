#!/usr/bin/env bash
# Phase 27 — Install Fluent Bit → CloudWatch logging
# Add to runbook — must run after every terraform apply
set -euo pipefail

helm repo add aws https://aws.github.io/eks-charts
helm repo update

# Install Fluent Bit as a DaemonSet
# DaemonSet = one pod per node, collects all container logs on that node
helm install aws-for-fluent-bit aws/aws-for-fluent-bit \
  --namespace amazon-cloudwatch \
  --create-namespace \
  --set cloudWatch.region=us-east-2 \
  --set cloudWatch.logGroupName=/pokeshop \
  --set cloudWatch.logStreamPrefix=from-host/

# This creates CloudWatch log groups:
#   /pokeshop/pokeshop-dev
#   /pokeshop/pokeshop-prod
#   /pokeshop/monitoring

kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=aws-for-fluent-bit \
  -n amazon-cloudwatch \
  --timeout=120s

kubectl get pods -n amazon-cloudwatch

echo "Fluent Bit installed ✓"
echo ""
echo "Logs will appear in CloudWatch under log group: /pokeshop"
echo "Query all errors across namespaces with Log Insights:"
echo "  fields @timestamp, @message, kubernetes.namespace_name, kubernetes.container_name"
echo "  | filter kubernetes.namespace_name in [\"pokeshop-dev\", \"pokeshop-prod\"]"
echo "  | filter @message like /ERROR|error|Error/"
echo "  | sort @timestamp desc"
echo "  | limit 100"
