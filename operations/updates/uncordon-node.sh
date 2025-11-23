#!/bin/bash
# Uncordon a Kubernetes node to bring it back online after updates
# Usage: ./uncordon-node.sh <node-name>

set -e

NODE=${1:-}

if [ -z "$NODE" ]; then
  echo "Usage: $0 <node-name>"
  echo ""
  echo "Example:"
  echo "  $0 k8s-worker-0"
  exit 1
fi

echo "=== Uncordoning node: $NODE ==="
echo ""

# Check if node exists
if ! kubectl get node "$NODE" &>/dev/null; then
  echo "ERROR: Node '$NODE' not found"
  exit 1
fi

# Check if node is ready
echo "Step 1: Checking node readiness..."
NODE_STATUS=$(kubectl get node "$NODE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')

if [ "$NODE_STATUS" != "True" ]; then
  echo "WARNING: Node is not Ready (status: $NODE_STATUS)"
  echo "         Waiting for node to become Ready..."
  echo ""

  # Wait for node to be ready
  timeout=300
  elapsed=0
  while [ "$NODE_STATUS" != "True" ] && [ $elapsed -lt $timeout ]; do
    sleep 5
    elapsed=$((elapsed + 5))
    NODE_STATUS=$(kubectl get node "$NODE" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
    echo "  [${elapsed}s] Node status: $NODE_STATUS"
  done

  if [ "$NODE_STATUS" != "True" ]; then
    echo "ERROR: Node did not become ready within ${timeout}s"
    echo "       Check kubelet status: ssh ubuntu@\$NODE_IP"
    echo "       sudo systemctl status kubelet"
    echo "       sudo journalctl -u kubelet -n 50"
    exit 1
  fi
fi

echo "Node $NODE is Ready ✓"
echo ""

# Uncordon the node
echo "Step 2: Uncordoning $NODE (making schedulable)..."
kubectl uncordon "$NODE"

echo ""
echo "Step 3: Waiting for pods to reschedule..."
echo "        Monitoring for 30 seconds..."
echo ""

# Show pod status for a bit
for i in {1..6}; do
  sleep 5
  PENDING=$(kubectl get pods -A --field-selector=status.phase=Pending -o json | jq '.items | length')
  RUNNING=$(kubectl get pods -A --field-selector=status.phase=Running -o json | jq '.items | length')
  echo "  [${i}0s] Running: $RUNNING | Pending: $PENDING"
done

echo ""
echo "=== Node uncordoning complete ==="
echo ""
echo "Node $NODE is now schedulable again."
echo ""
echo "To verify full cluster health:"
echo "  kubectl get nodes"
echo "  kubectl get pods -A | grep -v Running | head -5"
echo "  kubectl top nodes"
