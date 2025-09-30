#!/bin/bash

# Kubernetes worker join script
# Parameters: MASTER_IP

set -e

MASTER_IP=${1}

if [ -z "$MASTER_IP" ]; then
    echo "Error: MASTER_IP is required"
    echo "Usage: $0 <master_ip>"
    exit 1
fi

echo "Joining Kubernetes cluster via master: $MASTER_IP"

# Function to get join command from master
get_join_command() {
    local max_attempts=30
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        echo "Attempt $attempt to get join command from master..."

        # Try to get the join command from master
        join_cmd=$(ssh -i /home/ubuntu/.ssh/id_ed25519 -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@${MASTER_IP} 'cat /tmp/join-command' 2>/dev/null)

        if [ $? -eq 0 ] && [ ! -z "$join_cmd" ]; then
            echo "Successfully retrieved join command"
            echo "$join_cmd" > /tmp/join-command
            return 0
        fi

        echo "Failed to get join command, waiting 30 seconds before retry..."
        sleep 30
        attempt=$((attempt + 1))
    done

    echo "Failed to get join command after $max_attempts attempts"
    return 1
}

# Get and execute join command
if get_join_command; then
    echo "Joining cluster..."
    sudo bash /tmp/join-command

    if [ $? -eq 0 ]; then
        echo "Successfully joined the cluster"
    else
        echo "Failed to join the cluster"
        exit 1
    fi
else
    echo "Could not retrieve join command from master"
    exit 1
fi