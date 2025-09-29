#!/bin/bash

# Fetch kubeconfig from master node
# Usage: ./get-kubeconfig.sh <master-ip> [output-file]

set -e

MASTER_IP=${1}
OUTPUT_FILE=${2:-"./kubeconfig"}

if [[ -z "$MASTER_IP" ]]; then
    echo "Usage: $0 <master-ip> [output-file]"
    echo "Example: $0 192.168.1.200 ~/.kube/config-k8s-cluster"
    exit 1
fi

echo "Fetching kubeconfig from master node at ${MASTER_IP}..."

# Fetch the kubeconfig file from master
ssh -o StrictHostKeyChecking=no ubuntu@${MASTER_IP} "sudo cat /etc/kubernetes/admin.conf" > ${OUTPUT_FILE}

# Update the server address to use the master IP instead of localhost
sed -i.bak "s|server: https://.*:6443|server: https://${MASTER_IP}:6443|g" ${OUTPUT_FILE}
rm -f ${OUTPUT_FILE}.bak

echo "Kubeconfig saved to: ${OUTPUT_FILE}"
echo ""
echo "To use this kubeconfig:"
echo "  export KUBECONFIG=${OUTPUT_FILE}"
echo "  kubectl get nodes"
echo ""
echo "Or merge with existing config:"
echo "  KUBECONFIG=~/.kube/config:${OUTPUT_FILE} kubectl config view --flatten > ~/.kube/config.new"
echo "  mv ~/.kube/config.new ~/.kube/config"