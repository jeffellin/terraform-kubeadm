# OS Updates and Patching Guide

This guide covers how to safely update the operating system on your Kubernetes nodes without disrupting workloads.

## Overview

Since `unattended-upgrades` is disabled on all nodes to prevent unexpected reboots during cluster operations, OS updates must be applied manually using one of the methods below.

**Key Principles:**
- Updates are coordinated, not automatic
- Workloads are gracefully drained before node updates
- Only one node updates at a time (for cluster stability)
- All changes are version-controlled via Terraform/Git

## Method 1: Rolling Updates via Terraform (Recommended)

This method updates VMs through Proxmox by updating the base image, then re-deploying nodes via Terraform.

### Prerequisites
- Access to Proxmox cluster
- Terraform state synchronized
- All workloads configured with pod disruption budgets (PDB) or anti-affinity rules

### Procedure

**Step 1: Update Base Image in Proxmox**

Connect to your Proxmox host and update the Ubuntu template/image:
```bash
ssh root@proxmox-host
# Update the base image or create a new one with latest patches
# The exact steps depend on your Proxmox setup (packer, cloud-init, etc.)
```

**Step 2: Update Terraform to Use New Image (if using versioned images)**

If your Terraform configuration references specific image versions/snapshots:
```hcl
# In modules/kubeadm-proxmox/variables.tf or your main.tf
variable "template_name" {
  default = "ubuntu-24.04-v20251130"  # Update version
}
```

**Step 3: Plan Terraform Changes**

```bash
cd examples/kubeadm-cluster
terraform plan -out=tfplan
```

Review the changes to ensure only OS/image updates are planned.

**Step 4: Apply Changes Node by Node**

To avoid cluster disruption, apply Terraform changes one node at a time:

```bash
# For each worker node
for i in {0..N}; do
  # Plan just this worker's destruction/recreation
  terraform apply -target=module.kubeadm.proxmox_vm_qemu.worker[$i] tfplan

  # Wait for node to rejoin cluster and workloads to reschedule
  kubectl get nodes -w
  # Ctrl+C when all pods are Running/Ready

  sleep 60
done

# Finally update master node
terraform apply -target=module.kubeadm.proxmox_vm_qemu.master[0] tfplan
```

**Step 5: Verify Cluster Health**

```bash
kubectl get nodes
kubectl get pods -A | grep -v Running
kubectl top nodes
```

## Method 2: In-Place OS Updates via SSH (For Immediate Security Patches)

Use this method for urgent security updates that don't require node recreation.

### Prerequisites
- SSH access to all nodes
- `kubectl` configured with cluster access
- ~30 minutes per node

### Procedure

**Step 1: Set Up Drain Script**

Use the provided `operations/updates/drain-node.sh` script to gracefully evict workloads:

```bash
./operations/updates/drain-node.sh worker-node-0
```

This:
- Marks node as unschedulable
- Drains pods with graceful termination
- Waits for all pods to move to other nodes
- Keeps the node in a paused state (doesn't delete node)

**Step 2: Apply OS Updates**

SSH into the drained node:
```bash
ssh ubuntu@worker-node-0-ip
```

Update the system:
```bash
sudo apt update
sudo apt upgrade -y  # for all updates
# OR for security-only updates:
sudo apt install -y unattended-upgrades
sudo unattended-upgrade

# If kernel was updated, reboot
sudo reboot
```

**Step 3: Bring Node Back Online**

Once node is back up, uncordon it:
```bash
./operations/updates/uncordon-node.sh worker-node-0
```

This:
- Makes the node schedulable again
- Waits for kubelet to become ready
- Monitors pod rescheduling

**Step 4: Verify and Repeat**

```bash
kubectl get nodes
# Repeat for next worker node
```

**Step 5: Update Master Node**

For the master node, be more careful:

```bash
# Drain master (control-plane pods will reschedule to themselves)
kubectl drain k8s-cluster-master --ignore-daemonsets --delete-emptydir-data \
  --pod-selector='!spec.nodeName' 2>/dev/null || true

# SSH and update
ssh ubuntu@master-ip
sudo apt update && sudo apt upgrade -y
sudo reboot

# Wait for control-plane pods to restart
kubectl get nodes -w

# Uncordon when ready
kubectl uncordon k8s-cluster-master
```

## Method 3: Scheduled OS Updates with Ansible (For Regular Maintenance)

For regular, scheduled update windows, use the provided Ansible playbook.

### Prerequisites
- Ansible installed locally
- SSH key-based authentication configured to all nodes
- `/etc/ansible/hosts` or inventory file configured

### Configuration

**Step 1: Set Up Ansible Inventory**

Create/update `operations/inventory.ini`:
```ini
[masters]
k8s-master ansible_host=192.168.1.211 ansible_user=ubuntu

[workers]
k8s-worker-0 ansible_host=192.168.1.212 ansible_user=ubuntu
k8s-worker-1 ansible_host=192.168.1.213 ansible_user=ubuntu

[all:vars]
ansible_ssh_private_key_file=~/.ssh/id_ed25519
```

**Step 2: Run the Update Playbook**

```bash
# Dry-run to see what would happen
ansible-playbook -i operations/inventory.ini \
  operations/updates/rolling-update.yml --check

# Actually apply updates
ansible-playbook -i operations/inventory.ini \
  operations/updates/rolling-update.yml
```

The playbook:
1. Drains each worker node sequentially
2. Applies OS updates
3. Reboots if necessary
4. Validates node is ready before moving to next
5. Updates master last

**Step 3: Verify Cluster**

```bash
kubectl get nodes
kubectl top nodes
kubectl get pods -A
```

## Security Update Frequency

**Ubuntu 24.04 LTS (Noble Numbat):**
- **Security patches**: Weekly
- **Important updates**: Bi-weekly
- **System reboots**: Only if kernel or critical system libraries are updated

**Recommended Schedule:**
- Check for updates: Weekly
- Apply security updates: Monthly maintenance window
- Full system updates: Quarterly with planned downtime

## Checking for Available Updates

Without re-enabling `unattended-upgrades`, check for updates manually:

```bash
# On each node
ssh ubuntu@node-ip
sudo apt update
sudo apt upgrade -s  # Simulate, don't apply

# Or check all nodes at once with Ansible
ansible all -i operations/inventory.ini -a "sudo apt upgrade -s"
```

## Handling Kernel Updates

If `apt upgrade` includes a new kernel:

```bash
# Check current kernel
uname -r

# After reboot, verify new kernel is loaded
uname -r

# If something breaks, you can boot the old kernel from GRUB menu
```

If you want to prevent kernel updates, you can hold the package:
```bash
sudo apt-mark hold linux-image-generic linux-headers-generic
```

## Rollback Procedure

If an update causes issues:

### For Terraform-Based Updates
```bash
# Revert to previous Terraform plan/state
git checkout HEAD~1 -- terraform/
terraform apply  # Recreates node with previous image
```

### For SSH-Based Updates
```bash
ssh ubuntu@node-ip
# If node still boots
sudo apt-get downgrade package-name

# If node won't boot
# Boot into previous kernel from GRUB
# Or recreate node via Terraform
```

## Monitoring Update Progress

Watch node and pod status during updates:

```bash
# Terminal 1: Watch nodes
kubectl get nodes -w

# Terminal 2: Watch pods
watch -n 2 'kubectl get pods -A | grep -vE "Running|Completed"'

# Terminal 3: Watch node resource usage
watch -n 2 'kubectl top nodes'
```

## Troubleshooting

### Node won't rejoin cluster after update
```bash
ssh ubuntu@node-ip
sudo systemctl restart kubelet
journalctl -u kubelet -n 50
```

### Pods stuck in Terminating state during drain
```bash
# Force delete (use carefully!)
kubectl delete pod POD_NAME -n NAMESPACE --grace-period=0 --force
```

### etcd issues after master update
```bash
# Check etcd health on master
ssh ubuntu@master-ip
sudo docker exec -it $(sudo docker ps --filter name=etcd -q) \
  etcdctl --endpoints=127.0.0.1:2379 endpoint health
```

### Can't drain a node
```bash
# Check for pods that prevent draining
kubectl describe pod POD_NAME -n NAMESPACE

# Add exception for problematic workloads in Terraform/values
# Or add toleration to allow rescheduling
```

## Related Documentation

- [Kubernetes Node Upgrade Guide](https://kubernetes.io/docs/tasks/administer-cluster/cluster-upgrade/)
- [Ubuntu 24.04 Security Updates](https://wiki.ubuntu.com/Releases)
- [Terraform Proxmox Provider](https://registry.terraform.io/providers/Telmate/proxmox/latest/docs)

## Support

For issues or questions about updates:
1. Check the troubleshooting section above
2. Review node/kubelet logs: `journalctl -u kubelet -n 100`
3. Check cluster events: `kubectl get events -A`
