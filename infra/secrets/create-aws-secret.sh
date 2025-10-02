#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CREDENTIALS_FILE="$SCRIPT_DIR/aws-credentials"

if [ ! -f "$CREDENTIALS_FILE" ]; then
  echo "Error: aws-credentials file not found!"
  echo "Please create $CREDENTIALS_FILE with your AWS credentials"
  echo "You can use aws-credentials.example as a template"
  exit 1
fi

# Source the credentials file
source "$CREDENTIALS_FILE"

# Validate required variables
if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
  echo "Error: AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY must be set in $CREDENTIALS_FILE"
  exit 1
fi

if [ -z "$R53_ZONE" ]; then
  echo "Error: R53_ZONE must be set in $CREDENTIALS_FILE"
  exit 1
fi

# Create namespaces if they don't exist
echo "Ensuring namespaces exist..."
kubectl create namespace cert-manager --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace external-dns --dry-run=client -o yaml | kubectl apply -f -

echo "Creating AWS credentials secret for cert-manager..."
kubectl create secret generic aws-credentials \
  --from-literal=access-key-id="$AWS_ACCESS_KEY_ID" \
  --from-literal=secret-access-key="$AWS_SECRET_ACCESS_KEY" \
  --namespace=cert-manager \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Creating AWS credentials secret for external-dns..."
kubectl create secret generic aws-credentials \
  --from-literal=access-key-id="$AWS_ACCESS_KEY_ID" \
  --from-literal=secret-access-key="$AWS_SECRET_ACCESS_KEY" \
  --namespace=external-dns \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Creating external-dns-config configmap..."
kubectl create configmap external-dns-config \
  --from-literal=zone-id="$R53_ZONE" \
  --namespace=external-dns \
  --dry-run=client -o yaml | kubectl apply -f -

echo ""
echo "AWS credentials secrets and configmap created successfully!"
echo "  - cert-manager/aws-credentials"
echo "  - external-dns/aws-credentials"
echo "  - external-dns/external-dns-config"