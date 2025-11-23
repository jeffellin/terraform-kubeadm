#!/bin/bash

# Fetch kubeconfig from master node using terraform outputs
# Usage: ./get-kubeconfig.sh [output-file]

set -e

OUTPUT_FILE=${1:-"./kubeconfig"}

# Get master IP from terraform output
echo "Getting master IP from terraform outputs..."
MASTER_IP=$(terraform output -raw master_ip 2>/dev/null)

if [[ -z "$MASTER_IP" ]]; then
    echo "Error: Could not get master IP from terraform outputs"
    echo "Make sure you have deployed the infrastructure with terraform apply"
    exit 1
fi

echo "Fetching kubeconfig from master node at ${MASTER_IP}..."

# Fetch the kubeconfig file from master
ssh -o StrictHostKeyChecking=no ubuntu@${MASTER_IP} "sudo cat /etc/kubernetes/admin.conf" > ${OUTPUT_FILE}

# Update the server address to use the master IP instead of localhost
sed -i.bak "s|server: https://.*:6443|server: https://${MASTER_IP}:6443|g" ${OUTPUT_FILE}
rm -f ${OUTPUT_FILE}.bak

# Get the full path
FULL_PATH=$(cd "$(dirname "${OUTPUT_FILE}")" && pwd)/$(basename "${OUTPUT_FILE}")

echo "Kubeconfig saved to: ${FULL_PATH}"
echo ""
echo "To use this kubeconfig:"
echo "  export KUBECONFIG=${FULL_PATH}"
echo "  kubectl get nodes"
echo ""
echo "Or merge with existing config:"
echo "  KUBECONFIG=~/.kube/config:${FULL_PATH} kubectl config view --flatten > ~/.kube/config.new"
echo "  mv ~/.kube/config.new ~/.kube/config"