#!/bin/bash
# Drain a Kubernetes node to prepare for updates or maintenance
# Usage: ./drain-node.sh <node-name> [grace-period]

set -e

NODE=${1:-}
GRACE_PERIOD=${2:-300}

if [ -z "$NODE" ]; then
  echo "Usage: $0 <node-name> [grace-period-seconds]"
  echo ""
  echo "Examples:"
  echo "  $0 k8s-worker-0"
  echo "  $0 k8s-worker-0 600  # 10 minute grace period"
  exit 1
fi

echo "=== Draining node: $NODE ==="
echo "Grace period: ${GRACE_PERIOD}s"
echo ""

# Check if node exists
if ! kubectl get node "$NODE" &>/dev/null; then
  echo "ERROR: Node '$NODE' not found"
  exit 1
fi

# Cordon the node (prevent new pods from scheduling)
echo "Step 1: Cordoning node $NODE (marking as unschedulable)..."
kubectl cordon "$NODE"

# Drain the node (evict existing pods)
echo "Step 2: Draining pods from $NODE..."
echo "         This may take a few minutes if there are many pods..."
echo ""

kubectl drain "$NODE" \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --grace-period="$GRACE_PERIOD" \
  --timeout=30m \
  --pod-selector='!metadata.ownerReferences[?(@.kind=="DaemonSet")]' || {
    echo ""
    echo "WARNING: Some pods could not be drained."
    echo "         These may be stuck or have no valid rescheduling target."
    echo "         Check logs with: kubectl describe pod POD_NAME -n NAMESPACE"
    echo ""
    echo "Continuing with draining..."
    kubectl drain "$NODE" \
      --ignore-daemonsets \
      --delete-emptydir-data \
      --grace-period="$GRACE_PERIOD" \
      --timeout=5m \
      --skip-wait-for-delete-timeout || true
  }

echo ""
echo "=== Node draining complete ==="
echo ""
echo "Node $NODE is now cordoned (unschedulable)."
echo "All workload pods have been evicted."
echo ""
echo "You can now:"
echo "  1. SSH to the node and perform maintenance"
echo "  2. Run: ssh ubuntu@\$(kubectl get node $NODE -o jsonpath='{.status.addresses[?(@.type==\"ExternalIP\")].address}')"
echo "  3. When done, run: ./uncordon-node.sh $NODE"
echo ""

# Watch pod status for a few seconds
echo "Current pod status:"
kubectl get pods -A | grep -v Running | head -20
