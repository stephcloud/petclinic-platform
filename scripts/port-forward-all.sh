#!/usr/bin/env bash
set -euo pipefail
#
# port-forward-all.sh — Interactive port-forward menu for dev cluster
#
# Lets you choose which service to port-forward.
# All services are in the dev cluster (eu-central-1, chelsea-cloud profile).
#
# Usage:
#   ./scripts/port-forward-all.sh
#

REGION="eu-central-1"
PROFILE="chelsea-cloud"
CLUSTER_NAME="petclinic-dev"

echo "============================================"
echo "  Port-Forward Menu — ${CLUSTER_NAME}"
echo "  Region: ${REGION}"
echo "============================================"
echo ""

# Ensure kubeconfig is current
aws eks update-kubeconfig \
  --name "${CLUSTER_NAME}" \
  --region "${REGION}" \
  --profile "${PROFILE}" >/dev/null 2>&1 || true

PS3=$'\nSelect a service to port-forward (Ctrl-C to quit): '

select SERVICE in \
  "api-gateway (petclinic-dev :8080 → localhost:8080)" \
  "argocd       (argocd        :9999 → localhost:9999)" \
  "grafana      (monitoring    :3000 → localhost:3000)" \
  "prometheus   (monitoring    :9090 → localhost:9090)" \
  "alertmanager (monitoring    :9093 → localhost:9093)" \
  "zipkin       (monitoring    :9411 → localhost:9411)"; do

  if [[ -z "${SERVICE:-}" ]]; then
    echo "Invalid option. Please try again."
    continue
  fi

  case "${SERVICE}" in
    "api-gateway"*) # petclinic-dev
      NAMESPACE="petclinic-dev"
      DEPLOYMENT="api-gateway"
      LOCAL_PORT=8080
      REMOTE_PORT=8080
      ;;
    "argocd"*)
      NAMESPACE="argocd"
      DEPLOYMENT="argocd-server"
      LOCAL_PORT=9999
      REMOTE_PORT=8080
      ;;
    "grafana"*)
      NAMESPACE="monitoring"
      DEPLOYMENT="kube-prometheus-stack-grafana"
      LOCAL_PORT=3000
      REMOTE_PORT=80
      ;;
    "prometheus"*)
      NAMESPACE="monitoring"
      DEPLOYMENT="kube-prometheus-stack-prometheus"
      LOCAL_PORT=9090
      REMOTE_PORT=9090
      ;;
    "alertmanager"*)
      NAMESPACE="monitoring"
      DEPLOYMENT="kube-prometheus-stack-alertmanager"
      LOCAL_PORT=9093
      REMOTE_PORT=9093
      ;;
    "zipkin"*)
      NAMESPACE="monitoring"
      DEPLOYMENT="zipkin"
      LOCAL_PORT=9411
      REMOTE_PORT=9411
      ;;
    *)
      echo "Unknown selection."
      exit 1
      ;;
  esac

  echo ""
  echo "Forwarding ${DEPLOYMENT} (${NAMESPACE}:${REMOTE_PORT}) → localhost:${LOCAL_PORT}"
  echo "Press Ctrl-C to stop."
  echo ""

  kubectl port-forward \
    -n "${NAMESPACE}" \
    "deployment/${DEPLOYMENT}" \
    "${LOCAL_PORT}:${REMOTE_PORT}"

done
