#!/usr/bin/env bash
set -euo pipefail

#
# env-status.sh — Show dev environment status
#
# Displays EKS nodegroup config, node readiness, pod status in
# petclinic-dev and monitoring, and estimated daily cost.
#
# Usage:
#   ./scripts/env-status.sh
#

REGION="eu-central-1"
PROFILE="chelsea-cloud"
CLUSTER_NAME="petclinic-dev"
NODEGROUP_NAME="petclinic-dev-nodes"

echo "============================================"
echo "  Environment Status: dev"
echo "  Region: ${REGION}"
echo "============================================"
echo ""

# --- EKS Node Group ---
echo "--- Node Group: ${NODEGROUP_NAME} ---"

NODEGROUP_STATUS=$(aws eks describe-nodegroup \
  --cluster-name "${CLUSTER_NAME}" \
  --nodegroup-name "${NODEGROUP_NAME}" \
  --region "${REGION}" \
  --profile "${PROFILE}" \
  --query 'nodegroup.status' \
  --output text 2>/dev/null || echo "NOT FOUND")

if [[ "${NODEGROUP_STATUS}" == "NOT FOUND" ]]; then
  echo "  Status: NOT FOUND"
else
  echo "  Status: ${NODEGROUP_STATUS}"

  SCALING=$(aws eks describe-nodegroup \
    --cluster-name "${CLUSTER_NAME}" \
    --nodegroup-name "${NODEGROUP_NAME}" \
    --region "${REGION}" \
    --profile "${PROFILE}" \
    --query 'nodegroup.scalingConfig' \
    --output json)

  MIN=$(echo "${SCALING}" | grep -o '"minSize": [0-9]*' | awk '{print $2}')
  MAX=$(echo "${SCALING}" | grep -o '"maxSize": [0-9]*' | awk '{print $2}')
  DESIRED=$(echo "${SCALING}" | grep -o '"desiredSize": [0-9]*' | awk '{print $2}')

  echo "  Scaling: desired=${DESIRED:-?}, min=${MIN:-?}, max=${MAX:-?}"

  INSTANCE_TYPE=$(aws eks describe-nodegroup \
    --cluster-name "${CLUSTER_NAME}" \
    --nodegroup-name "${NODEGROUP_NAME}" \
    --region "${REGION}" \
    --profile "${PROFILE}" \
    --query 'nodegroup.instanceTypes[0]' \
    --output text)
  echo "  Instance type: ${INSTANCE_TYPE}"
fi
echo ""

# --- Nodes ---
echo "--- Kubernetes Nodes ---"
READY_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready " || true)
TOTAL_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | wc -l || true)
echo "  Ready: ${READY_COUNT:-0} / ${TOTAL_COUNT:-0}"
kubectl get nodes --no-headers 2>/dev/null || echo "  (unable to reach cluster — run start-env.sh first)"
echo ""

# --- Pods: petclinic-dev ---
echo "--- Pods: petclinic-dev ---"
kubectl get pods -n petclinic-dev --no-headers 2>/dev/null | head -n 15 || echo "  (namespace not found or cluster unreachable)"
RUNNING_DEV=$(kubectl get pods -n petclinic-dev --no-headers 2>/dev/null | grep -c "Running" || true)
TOTAL_DEV=$(kubectl get pods -n petclinic-dev --no-headers 2>/dev/null | wc -l || true)
echo "  → ${RUNNING_DEV:-0}/${TOTAL_DEV:-0} Running"
echo ""

# --- Pods: monitoring ---
echo "--- Pods: monitoring ---"
kubectl get pods -n monitoring --no-headers 2>/dev/null | head -n 15 || echo "  (namespace not found or cluster unreachable)"
RUNNING_MON=$(kubectl get pods -n monitoring --no-headers 2>/dev/null | grep -c "Running" || true)
TOTAL_MON=$(kubectl get pods -n monitoring --no-headers 2>/dev/null | wc -l || true)
echo "  → ${RUNNING_MON:-0}/${TOTAL_MON:-0} Running"
echo ""

# --- Cost Estimate ---
echo "--- Estimated Daily Cost ---"

EKS_CP_COST=3.30
NODE_COST=3.50
TOTAL_COST="${EKS_CP_COST}"

echo "  EKS control plane:  ~\$${EKS_CP_COST}/day (always on)"

if [[ "${DESIRED:-0}" != "0" ]]; then
  echo "  EC2 nodes (t3.medium): ~\$${NODE_COST}/day (while running)"
  TOTAL_COST=$(awk "BEGIN {printf \"%.2f\", $EKS_CP_COST + $NODE_COST}")
else
  echo "  EC2 nodes:           ~\$0/day (scaled to 0)"
fi

echo ""
echo "  Total (approx):    ~\$${TOTAL_COST}/day"

if [[ "${DESIRED:-0}" == "0" ]]; then
  echo ""
  echo "  ⏸  Environment is PAUSED — only control plane costs apply."
  echo "     Run ./scripts/start-env.sh to resume."
else
  echo ""
  echo "  ▶  Environment is RUNNING."
  echo "     Run ./scripts/stop-env.sh to pause."
fi
echo "============================================"
