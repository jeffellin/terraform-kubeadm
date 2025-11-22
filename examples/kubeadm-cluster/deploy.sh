#!/bin/bash
set -euo pipefail

# Script to deploy Kubernetes cluster with 1Password SSH key integration
# Prerequisites:
#   - 1Password CLI installed (op)
#   - 1Password vault configured and authenticated
#   - Public SSH key stored in 1Password vault as "cloudimg"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT_NAME="${VAULT_NAME:-Private}"
KEY_NAME="cloudimg"
TERRAFORM_DIR="$SCRIPT_DIR"

echo "🔐 Kubernetes Cluster Deployment Script"
echo "======================================="

# Check if 1Password CLI is installed
if ! command -v op &> /dev/null; then
  echo "❌ Error: 1Password CLI (op) not found. Please install it first:"
  echo "   https://developer.1password.com/docs/cli/get-started/"
  exit 1
fi

# Check if terraform is installed
if ! command -v terraform &> /dev/null; then
  echo "❌ Error: Terraform not found. Please install it first."
  exit 1
fi

# Verify 1Password authentication
echo "🔑 Checking 1Password authentication..."
if ! op vault list > /dev/null 2>&1; then
  echo "⚠️  1Password not authenticated. Signing in..."
  eval "$(op signin)"
fi

# Retrieve SSH public key from 1Password
echo "📦 Retrieving SSH public key from 1Password vault: $VAULT_NAME"
SSH_PUBLIC_KEY=$(op item get "$KEY_NAME" --vault "$VAULT_NAME" --field 'public key' 2>/dev/null || \
                 op read "op://$VAULT_NAME/$KEY_NAME/public key" 2>/dev/null || \
                 op read "op://$VAULT_NAME/$KEY_NAME/public_key" 2>/dev/null)

if [ -z "$SSH_PUBLIC_KEY" ]; then
  echo "❌ Error: Could not retrieve SSH public key from 1Password"
  echo "   Vault: $VAULT_NAME"
  echo "   Item: $KEY_NAME"
  echo "   Expected field: public_key"
  exit 1
fi

echo "✅ SSH public key retrieved successfully"
echo "   Key starts with: ${SSH_PUBLIC_KEY:0:30}..."

# Export as Terraform variable
export TF_VAR_ssh_public_key="$SSH_PUBLIC_KEY"

# Change to terraform directory
cd "$TERRAFORM_DIR"

echo ""
echo "📋 Terraform Configuration:"
echo "   Directory: $TERRAFORM_DIR"
echo "   SSH Public Key: ${SSH_PUBLIC_KEY:0:40}... (truncated)"

# Run terraform apply
echo ""
echo "🚀 Running terraform apply..."
terraform apply -auto-approve

# Extract cluster SSH key from terraform state
echo ""
echo "🔑 Extracting cluster SSH private key..."

terraform show -json > /tmp/tf-state.json

python3 << 'PYTHON_EOF'
import json
import os
import sys

try:
    with open('/tmp/tf-state.json', 'r') as f:
        tf_state = json.load(f)

    # Navigate through the state structure
    child_modules = tf_state.get('values', {}).get('root_module', {}).get('child_modules', [])

    for module in child_modules:
        resources = module.get('resources', [])
        for resource in resources:
            if resource.get('type') == 'tls_private_key':
                private_key = resource.get('values', {}).get('private_key_openssh')
                if private_key:
                    output_path = 'cluster-ssh-key'
                    with open(output_path, 'w') as f:
                        f.write(private_key)
                    os.chmod(output_path, 0o600)
                    print(f"✅ Cluster SSH key saved to: {output_path}")
                    print(f"   Permissions: 600 (read/write for owner only)")
                    sys.exit(0)

    print("❌ Error: Could not find tls_private_key in terraform state", file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f"❌ Error extracting SSH key: {e}", file=sys.stderr)
    sys.exit(1)
PYTHON_EOF

if [ $? -ne 0 ]; then
  echo "❌ Failed to extract cluster SSH key"
  exit 1
fi

# Display connection information
echo ""
echo "✨ Deployment Complete!"
echo "======================="
echo ""
echo "Master Node:"
MASTER_IP=$(terraform output -raw master_ip)
echo "  IP: $MASTER_IP"
echo "  SSH: ssh -i cluster-ssh-key ubuntu@$MASTER_IP"
echo ""
echo "Worker Nodes:"
WORKER_IPS=$(terraform output -json worker_ips | jq -r '.[]')
for IP in $WORKER_IPS; do
  echo "  IP: $IP"
  echo "  SSH: ssh -i cluster-ssh-key ubuntu@$IP"
done

echo ""
echo "📝 Notes:"
echo "  - Your 1Password SSH key is now authorized on all VMs"
echo "  - Use cluster-ssh-key for automated deployments"
echo "  - Your personal SSH key can be used with: ssh -i ~/.ssh/id_rsa ubuntu@<IP>"
echo ""
