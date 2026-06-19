#!/bin/bash
set -e

# ─────────────────────────────────────────────
# Bootstrap Terraform State Backend
# Creates S3 bucket + DynamoDB table for state
# Safe to run multiple times (idempotent)
# ─────────────────────────────────────────────

REGION="${1:-us-east-1}"
PROFILE="${AWS_PROFILE:-chelsea-cloud}"

echo "Using AWS profile: $PROFILE"
echo "Using region: $REGION"

# Get account ID
ACCOUNT_ID=$(aws sts get-caller-identity \
  --query Account --output text --profile $PROFILE)

BUCKET_NAME="petclinic-terraform-state-${ACCOUNT_ID}"
DYNAMO_TABLE="petclinic-terraform-locks"

echo ""
echo "State bucket : $BUCKET_NAME"
echo "Lock table   : $DYNAMO_TABLE"
echo ""

# ── S3 Bucket ──────────────────────────────
echo "Creating S3 bucket..."
aws s3 mb s3://${BUCKET_NAME} \
  --region ${REGION} \
  --profile ${PROFILE} 2>/dev/null || echo "  Bucket already exists — skipping"

echo "Enabling versioning..."
aws s3api put-bucket-versioning \
  --bucket ${BUCKET_NAME} \
  --versioning-configuration Status=Enabled \
  --profile ${PROFILE}

echo "Blocking public access..."
aws s3api put-public-access-block \
  --bucket ${BUCKET_NAME} \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true \
  --profile ${PROFILE}

echo "Enabling encryption..."
aws s3api put-bucket-encryption \
  --bucket ${BUCKET_NAME} \
  --server-side-encryption-configuration \
    '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}' \
  --profile ${PROFILE}

# ── DynamoDB Table ──────────────────────────
echo "Creating DynamoDB lock table..."
aws dynamodb create-table \
  --table-name ${DYNAMO_TABLE} \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ${REGION} \
  --profile ${PROFILE} 2>/dev/null || echo "  Table already exists — skipping"

echo ""
echo "✅ Bootstrap complete!"
echo ""
echo "Add this to your backend.tf:"
echo "────────────────────────────────────────"
echo "terraform {"
echo "  backend \"s3\" {"
echo "    bucket         = \"${BUCKET_NAME}\""
echo "    key            = \"petclinic/dev/terraform.tfstate\""
echo "    region         = \"${REGION}\""
echo "    dynamodb_table = \"${DYNAMO_TABLE}\""
echo "    encrypt        = true"
echo "  }"
echo "}"
echo "────────────────────────────────────────"
