#!/usr/bin/env bash
set -euo pipefail
#
# stop-env.sh — Stop the dev EKS environment
#
# Scales nodegroup to 0 nodes to save compute cost.
# EKS control plane remains running (~$3.30/day).
#
# Usage:
#   ./scripts/stop-env.sh
#

REGION="eu-central-1"
PROFILE="chelsea-cloud"
CLUSTER_NAME="petclinic-dev"
NODEGROUP_NAME="petclinic-dev-nodes"

echo "============================================"
echo "  Stopping dev environment"
echo "  Cluster: ${CLUSTER_NAME}"
echo "  Region:  ${REGION}"
echo "============================================"
echo ""

echo "[1/1] Scaling nodegroup ${NODEGROUP_NAME} → desired=0, min=0, max=4"
aws eks update-nodegroup-config \
  --cluster-name "${CLUSTER_NAME}" \
  --nodegroup-name "${NODEGROUP_NAME}" \
  --scaling-config minSize=0,maxSize=4,desiredSize=0 \
  --region "${REGION}" \
  --profile "${PROFILE}" >/dev/null

echo "  -> Nodes scaling down to 0."
echo ""
echo "============================================"
echo "  Dev environment paused."
echo ""
echo "  Running costs now: ~$3.30/day (EKS control plane only)"
echo "  Stopped costs:     ~$0/day (nodes scaled to 0)"
echo ""
echo "  Run ./scripts/start-env.sh to resume."
echo "============================================"
