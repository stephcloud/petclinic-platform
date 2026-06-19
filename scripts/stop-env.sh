#!/bin/bash
set -e

ENV=${1:-dev}
CLUSTER_NAME="petclinic-${ENV}"
REGION="eu-central-1"
PROFILE="chelsea-cloud"

echo "Stopping environment: $ENV"

# Scale EKS nodes to 0
echo "Scaling EKS nodes to 0..."
aws eks update-nodegroup-config \
  --cluster-name ${CLUSTER_NAME} \
  --nodegroup-name ${CLUSTER_NAME}-nodes \
  --scaling-config minSize=0,maxSize=4,desiredSize=0 \
  --region ${REGION} \
  --profile ${PROFILE}

echo "✅ Done! Nodes scaling down."
echo "Cost overnight: ~$0.80 (EKS control plane only)"
echo "Run start-env.sh tomorrow to resume."
