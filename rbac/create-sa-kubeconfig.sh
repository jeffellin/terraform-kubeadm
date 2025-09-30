#!/bin/bash

set -e

# Check parameters
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <namespace> <serviceaccount-name>"
    echo "Example: $0 default wordpress-portforward"
    exit 1
fi

NAMESPACE=$1
SA_NAME=$2

echo "Creating kubeconfig for service account: ${SA_NAME} in namespace: ${NAMESPACE}"

# Create token for the service account
SA_TOKEN=$(kubectl -n "${NAMESPACE}" create token "${SA_NAME}")

# Get cluster information
CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')
CLUSTER_SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
CA_DATA=$(kubectl config view --raw --minify -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')

# Output kubeconfig file name
KUBECONFIG_FILE="${SA_NAME}.kubeconfig"

# Create the kubeconfig
cat <<EOF > "${KUBECONFIG_FILE}"
apiVersion: v1
kind: Config
clusters:
- name: ${CLUSTER_NAME}
  cluster:
    certificate-authority-data: ${CA_DATA}
    server: ${CLUSTER_SERVER}
contexts:
- name: ${SA_NAME}-context
  context:
    cluster: ${CLUSTER_NAME}
    namespace: ${NAMESPACE}
    user: ${SA_NAME}
current-context: ${SA_NAME}-context
users:
- name: ${SA_NAME}
  user:
    token: ${SA_TOKEN}
EOF

echo "Kubeconfig created: ${KUBECONFIG_FILE}"
echo "To use this kubeconfig, run:"
echo "  export KUBECONFIG=$(pwd)/${KUBECONFIG_FILE}"
echo ""
echo "Or source it directly:"
echo "  source <(echo \"export KUBECONFIG=$(pwd)/${KUBECONFIG_FILE}\")"