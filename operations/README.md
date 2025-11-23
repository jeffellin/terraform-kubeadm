# Kubernetes Cluster Operations

This directory contains operational tools and documentation for managing your Kubernetes cluster after deployment.

## Contents

### Documentation

- **[OS_UPDATES.md](../docs/operations/OS_UPDATES.md)** - Comprehensive guide for updating the operating system on cluster nodes
  - Three methods: Terraform, SSH, and Ansible
  - Security update strategies
  - Rollback procedures

### Scripts

#### Updates Directory (`updates/`)

**drain-node.sh**
- Gracefully drain a node for maintenance
- Cordons the node and evicts all workload pods
- Usage: `./updates/drain-node.sh <node-name>`

**uncordon-node.sh**
- Bring a node back online after maintenance
- Waits for node to become Ready
- Allows workload pods to reschedule
- Usage: `./updates/uncordon-node.sh <node-name>`

**rolling-update.yml**
- Ansible playbook for automated rolling OS updates
- Updates one node at a time with full verification
- Handles reboots and kubelet restart
- Usage: `ansible-playbook -i inventory.ini updates/rolling-update.yml`

**inventory.ini.example**
- Ansible inventory template
- Copy to `inventory.ini` and update with your node IPs
- Usage: `cp inventory.ini.example inventory.ini`

## Quick Start

### Method 1: Manual Updates via SSH (Fast for 1-2 nodes)

```bash
# Drain the node
./updates/drain-node.sh k8s-worker-0

# SSH and update
ssh ubuntu@192.168.1.212
sudo apt update && sudo apt upgrade -y
sudo reboot

# Bring node back
./updates/uncordon-node.sh k8s-worker-0
```

### Method 2: Automated with Ansible (Best for regular maintenance)

```bash
# Set up inventory
cp inventory.ini.example inventory.ini
# Edit inventory.ini with your node IPs

# Dry-run to see what will happen
ansible-playbook -i inventory.ini updates/rolling-update.yml --check

# Apply updates
ansible-playbook -i inventory.ini updates/rolling-update.yml
```

### Method 3: Via Terraform (For complete OS refresh)

See [OS_UPDATES.md - Method 1](../docs/operations/OS_UPDATES.md#method-1-rolling-updates-via-terraform-recommended)

## Prerequisites

### For drain/uncordon scripts
- `kubectl` configured with cluster access
- Kubeconfig in `$HOME/.kube/config` or `$KUBECONFIG`

### For Ansible playbook
- Ansible installed: `pip install ansible`
- SSH key-based auth to all nodes
- `kubectl` available locally
- Inventory file configured

### For Terraform method
- Terraform configured with Proxmox provider
- Access to Proxmox cluster
- Updated base VM image

## Node Discovery

Get your cluster node information:

```bash
# List all nodes with IPs
kubectl get nodes -o wide

# Get only external IPs
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.addresses[?(@.type=="ExternalIP")].address}{"\n"}{end}'

# Get node roles
kubectl get nodes --show-labels | grep node-role
```

## Update Strategies

### Security Updates Only (Weekly)
```bash
# Check what would be updated
ansible all -i inventory.ini -a "apt upgrade -s" | grep security

# Apply security updates only
ansible all -i inventory.ini -a "apt upgrade -s && apt install -y unattended-upgrades && unattended-upgrade"
```

### Full System Updates (Quarterly)
```bash
# Use rolling update playbook
ansible-playbook -i inventory.ini updates/rolling-update.yml
```

### Immediate Critical Updates (Out of band)
```bash
# Manual method for urgent patches
./updates/drain-node.sh target-node
ssh ubuntu@node-ip "sudo apt install package-name"
./updates/uncordon-node.sh target-node
```

## Monitoring Updates

Watch cluster health during updates:

```bash
# Terminal 1: Watch nodes
watch kubectl get nodes

# Terminal 2: Watch pods
watch 'kubectl get pods -A | grep -vE "Running|Completed"'

# Terminal 3: Monitor events
kubectl get events -A -w
```

## Troubleshooting

### Node stuck in draining
```bash
# Check what pods prevent draining
kubectl describe pod POD_NAME -n NAMESPACE

# Force evict if necessary (careful!)
kubectl delete pod POD_NAME -n NAMESPACE --grace-period=0 --force
```

### Node won't rejoin after update
```bash
ssh ubuntu@node-ip
sudo systemctl restart kubelet
journalctl -u kubelet -n 50
```

### etcd issues after master update
```bash
# Check etcd health
ssh ubuntu@master-ip
sudo docker exec $(sudo docker ps --filter name=etcd -q) \
  etcdctl endpoint health
```

## Related Documentation

- [OS_UPDATES.md](../docs/operations/OS_UPDATES.md) - Detailed update procedures
- [MAINTENANCE.md](../docs/operations/MAINTENANCE.md) - Regular maintenance tasks (coming soon)
- [UPGRADES.md](../docs/operations/UPGRADES.md) - Kubernetes version upgrades (coming soon)
- [Kubernetes Drain Documentation](https://kubernetes.io/docs/tasks/administer-cluster/safely-drain-a-node/)

## Support

For issues:
1. Check [OS_UPDATES.md troubleshooting](../docs/operations/OS_UPDATES.md#troubleshooting)
2. Review kubelet logs: `journalctl -u kubelet -f`
3. Check cluster events: `kubectl get events -A`
4. Review Ansible playbook output for specific error messages
