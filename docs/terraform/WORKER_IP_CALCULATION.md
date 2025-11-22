# Worker IP Calculation

## Smart IP Assignment

The module now automatically calculates worker IPs based on the master IP, preventing IP conflicts.

## How It Works

### Default Behavior (Auto-Calculate)

When `worker_ip_start = -1` (the default), the module:

1. **Extracts** the last octet from `master_ip`
2. **Calculates** worker start IP as: `master_ip_last_octet + 1`
3. **Assigns** each worker an IP incrementally

### Formula

```
worker_N_ip = master_ip_prefix.{master_ip_octet + N}
```

## Examples

### Example 1: Default Configuration

```hcl
master_ip        = "192.168.1.200"
worker_ip_prefix = "192.168.1"
worker_ip_start  = -1  # auto-calculate
worker_count     = 3
```

| Node | IP |
|------|-----|
| Master | `192.168.1.200` |
| Worker 1 | `192.168.1.201` |
| Worker 2 | `192.168.1.202` |
| Worker 3 | `192.168.1.203` |

### Example 2: Master at Different IP

```hcl
master_ip        = "192.168.1.205"
worker_ip_prefix = "192.168.1"
worker_ip_start  = -1  # auto-calculate
worker_count     = 3
```

| Node | IP |
|------|-----|
| Master | `192.168.1.205` |
| Worker 1 | `192.168.1.206` |
| Worker 2 | `192.168.1.207` |
| Worker 3 | `192.168.1.208` |

**No conflict!** Workers automatically start after the master.

### Example 3: Different Network

```hcl
master_ip        = "10.0.0.100"
worker_ip_prefix = "10.0.0"
worker_ip_start  = -1  # auto-calculate
worker_count     = 5
```

| Node | IP |
|------|-----|
| Master | `10.0.0.100` |
| Worker 1 | `10.0.0.101` |
| Worker 2 | `10.0.0.102` |
| Worker 3 | `10.0.0.103` |
| Worker 4 | `10.0.0.104` |
| Worker 5 | `10.0.0.105` |

## Manual Override

If you want to explicitly control where workers start, use `worker_ip_start`:

```hcl
master_ip        = "192.168.1.200"
worker_ip_prefix = "192.168.1"
worker_ip_start  = 250  # explicitly start at .250
worker_count     = 3
```

| Node | IP |
|------|-----|
| Master | `192.168.1.200` |
| Worker 1 | `192.168.1.250` |
| Worker 2 | `192.168.1.251` |
| Worker 3 | `192.168.1.252` |

## Usage Examples

### Terraform Command Line

Auto-calculate workers after master:
```bash
terraform apply \
  -var="master_ip=192.168.1.205" \
  -var="worker_count=3"
```

Explicitly set worker start:
```bash
terraform apply \
  -var="master_ip=192.168.1.200" \
  -var="worker_ip_start=210" \
  -var="worker_count=3"
```

### In Terraform Code

```hcl
module "kubeadm_cluster" {
  source = "../../modules/kubeadm-proxmox"

  proxmox_host     = var.proxmox_host
  proxmox_username = var.proxmox_username
  proxmox_password = var.proxmox_password
  proxmox_node     = var.proxmox_node
  storage_pool     = var.storage_pool
  network_bridge   = var.network_bridge

  # Auto-calculate workers after master
  master_ip        = "10.0.0.100"
  worker_ip_prefix = "10.0.0"
  worker_ip_start  = -1  # auto-calculate
  worker_count     = 5
}
```

Or with explicit control:

```hcl
module "kubeadm_cluster" {
  source = "../../modules/kubeadm-proxmox"

  # ... required variables ...

  # Manually specify all IP ranges
  master_ip        = "172.16.0.100"
  worker_ip_prefix = "172.16.0"
  worker_ip_start  = 110  # workers start at .110
  worker_count     = 10
}
```

## Implementation Details

The calculation happens in the module's `locals` block:

```hcl
locals {
  # Extract the last octet from master IP
  master_ip_octet = tonumber(split(".", var.master_ip)[3])

  # Use provided value, or auto-calculate as master_ip + 1
  worker_ip_start = var.worker_ip_start >= 0 ? var.worker_ip_start : local.master_ip_octet + 1

  # Create worker nodes with correct IPs
  worker_nodes = {
    for i in range(1, var.worker_count + 1) : tostring(i) => {
      ip    = local.worker_ip_start + i - 1
      vm_id = local.worker_ip_start + i - 1
    }
  }
}
```

## Variables Reference

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `master_ip` | string | `192.168.1.200` | Master node IP address |
| `worker_ip_prefix` | string | `192.168.1` | IP prefix for workers |
| `worker_ip_start` | number | `-1` | First worker IP octet (-1 = auto) |
| `worker_count` | number | `3` | Number of workers |

## Troubleshooting

### IP conflicts occur

**Check:** Are master and first worker on the same IP?

**Solution:** Ensure either:
1. `worker_ip_start = -1` (auto-calculate)
2. `worker_ip_start > master_ip_last_octet` (if manual)

Example fix:
```bash
terraform apply -var="worker_ip_start=210"
```

### Workers can't reach master

**Check:** Are all nodes in the same subnet?

**Solution:** Ensure `worker_ip_prefix` matches the network of `master_ip`

Example:
```bash
# Both should use same prefix
terraform apply \
  -var="master_ip=10.0.0.100" \
  -var="worker_ip_prefix=10.0.0"
```

### IPs don't match expectations

**Check:** Print the calculated values

```bash
# See what IPs will be assigned
terraform plan | grep "address ="
```

## Related Documentation

- [Module Setup Guide](MODULE_SETUP.md) - Understanding the module structure
- [Examples](EXAMPLES.md) - Practical usage patterns
- [Getting Started](../GETTING_STARTED.md) - Quick start guide
- [Back to Docs Index](../../README.md) - Main documentation
