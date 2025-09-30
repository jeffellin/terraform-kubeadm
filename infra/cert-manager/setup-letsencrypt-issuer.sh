#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CREDENTIALS_FILE="$SCRIPT_DIR/../secrets/aws-credentials"

if [ ! -f "$CREDENTIALS_FILE" ]; then
  echo "Error: aws-credentials file not found!"
  echo "Please create $CREDENTIALS_FILE with your AWS credentials"
  echo "Run: ../secrets/create-aws-secret.sh first"
  exit 1
fi

# Source the credentials file
source "$CREDENTIALS_FILE"

# Validate required variables
if [ -z "$R53_ZONE" ]; then
  echo "Error: R53_ZONE must be set in $CREDENTIALS_FILE"
  exit 1
fi

# Prompt for email if not set
if [ -z "$CERT_EMAIL" ]; then
  read -p "Enter email for Let's Encrypt notifications: " CERT_EMAIL
  if [ -z "$CERT_EMAIL" ]; then
    echo "Error: Email is required for Let's Encrypt"
    exit 1
  fi
fi

echo "Setting up Let's Encrypt ClusterIssuers with Route53 DNS challenge..."
echo "  Zone ID: $R53_ZONE"
echo "  Email: $CERT_EMAIL"
echo ""

# Create staging issuer
cat <<EOF | kubectl apply -f -
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-staging
spec:
  acme:
    server: https://acme-staging-v02.api.letsencrypt.org/directory
    email: $CERT_EMAIL
    privateKeySecretRef:
      name: letsencrypt-staging
    solvers:
    - dns01:
        route53:
          region: ${AWS_REGION:-us-east-1}
          hostedZoneID: $R53_ZONE
          accessKeyIDSecretRef:
            name: aws-credentials
            key: access-key-id
          secretAccessKeySecretRef:
            name: aws-credentials
            key: secret-access-key
EOF

echo ""
echo "✓ Created letsencrypt-staging ClusterIssuer"
echo ""

# Create production issuer
cat <<EOF | kubectl apply -f -
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: $CERT_EMAIL
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - dns01:
        route53:
          region: ${AWS_REGION:-us-east-1}
          hostedZoneID: $R53_ZONE
          accessKeyIDSecretRef:
            name: aws-credentials
            key: access-key-id
          secretAccessKeySecretRef:
            name: aws-credentials
            key: secret-access-key
EOF

echo ""
echo "✓ Created letsencrypt-prod ClusterIssuer"
echo ""
echo "Let's Encrypt ClusterIssuers setup complete!"
echo ""
echo "To verify:"
echo "  kubectl get clusterissuer"
echo "  kubectl describe clusterissuer letsencrypt-staging"
echo "  kubectl describe clusterissuer letsencrypt-prod"
echo ""
echo "IMPORTANT: Test with letsencrypt-staging first before using letsencrypt-prod"
echo "           to avoid rate limits."