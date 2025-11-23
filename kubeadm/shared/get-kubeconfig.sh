#!/bin/bash

# Fetch kubeconfig from master node
# Usage: ./get-kubeconfig.sh <master-ip> [output-file]
# Or source: source get-kubeconfig.sh && fetch_kubeconfig <master-ip> [output-file]

set -e

fetch_kubeconfig() {
    local MASTER_IP=${1}
    local OUTPUT_FILE=${2:-"./kubeconfig"}

    if [[ -z "$MASTER_IP" ]]; then
        echo "Usage: fetch_kubeconfig <master-ip> [output-file]"
        echo "Example: fetch_kubeconfig 192.168.1.200 ~/.kube/config-k8s-cluster"
        return 1
    fi

    echo "Fetching kubeconfig from master node at ${MASTER_IP}..."

    # Fetch the kubeconfig file from master
    ssh -o StrictHostKeyChecking=no ubuntu@${MASTER_IP} "sudo cat /etc/kubernetes/admin.conf" > ${OUTPUT_FILE}

    # Update the server address to use the master IP instead of localhost
    sed -i.bak "s|server: https://.*:6443|server: https://${MASTER_IP}:6443|g" ${OUTPUT_FILE}
    rm -f ${OUTPUT_FILE}.bak

    # Get the full path
    local FULL_PATH=$(cd "$(dirname "${OUTPUT_FILE}")" && pwd)/$(basename "${OUTPUT_FILE}")

    echo "Kubeconfig saved to: ${FULL_PATH}"
    echo ""
    echo "To use this kubeconfig:"
    echo "  export KUBECONFIG=${FULL_PATH}"
    echo "  kubectl get nodes"
    echo ""
    echo "Or merge with existing config:"
    echo "  KUBECONFIG=~/.kube/config:${FULL_PATH} kubectl config view --flatten > ~/.kube/config.new"
    echo "  mv ~/.kube/config.new ~/.kube/config"
}

# Only execute if script is run directly, not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    fetch_kubeconfig "$@"
fi