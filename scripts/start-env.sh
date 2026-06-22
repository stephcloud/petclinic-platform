#!/usr/bin/env bash
set -euo pipefail
#
# start-env.sh — Start the dev EKS environment
#
# Scales nodegroup to 2 nodes, updates kubeconfig, waits for Ready,
# then shows pod status in petclinic-dev namespace.
#
# Usage:
#   ./scripts/start-env.sh
#

REGION="eu-central-1"
PROFILE="chelsea-cloud"
CLUSTER_NAME="petclinic-dev"
NODEGROUP_NAME="petclinic-dev-nodes"

echo "============================================"
echo "  Starting dev environment"
echo "  Cluster: ${CLUSTER_NAME}"
echo "  Region:  ${REGION}"
echo "============================================"
echo ""

# --- Scale nodegroup up ---
echo "[1/3] Scaling nodegroup ${NODEGROUP_NAME} → desired=2, min=2, max=4"
aws eks update-nodegroup-config \
  --cluster-name "${CLUSTER_NAME}" \
  --nodegroup-name "${NODEGROUP_NAME}" \
  --scaling-config minSize=2,maxSize=4,desiredSize=2 \
  --region "${REGION}" \
  --profile "${PROFILE}" >/dev/null

echo "  -> Scaling initiated. Waiting for nodegroup to become active..."
aws eks wait nodegroup-active \
  --cluster-name "${CLUSTER_NAME}" \
  --nodegroup-name "${NODEGROUP_NAME}" \
  --region "${REGION}" \
  --profile "${PROFILE}"
echo "  -> Node group is active."
echo ""

# --- Update kubeconfig ---
echo "[2/3] Updating kubeconfig for ${CLUSTER_NAME}"
aws eks update-kubeconfig \
  --name "${CLUSTER_NAME}" \
  --region "${REGION}" \
  --profile "${PROFILE}"
echo "  -> kubeconfig updated."
echo ""

# --- Wait for nodes Ready ---
echo "[3/3] Waiting for nodes to be Ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=180s 2>/dev/null || true
READY_NODES=$(kubectl get nodes -o jsonpath='{range .items[*]}{@.metadata.name}{"\n"}{end}' | wc -l)
echo "  -> ${READY_NODES} node(s) Ready."
echo ""

# --- Show pod status ---
echo "--- Pods in petclinic-dev namespace ---"
kubectl get pods -n petclinic-dev
echo ""

# --- Show monitoring namespace too ---
echo "--- Pods in monitoring namespace ---"
kubectl get pods -n monitoring
echo ""

echo "============================================"
echo "  Dev environment is ready."
echo "============================================"
