terraform {
  required_version = ">= 1.0"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.40.0"
    }
  }
}

module "kubeadm_cluster" {
  source = "../../modules/kubeadm-proxmox"

  # Required parameters
  proxmox_host     = var.proxmox_host
  proxmox_username = var.proxmox_username
  proxmox_password = var.proxmox_password
  proxmox_node     = var.proxmox_node
  storage_pool     = var.storage_pool
  network_bridge   = var.network_bridge

  # Optional parameters with defaults that can be overridden
  vm_password      = var.vm_password
  ssh_public_key   = var.ssh_public_key
  ubuntu_iso_path  = var.ubuntu_iso_path
  template_id      = var.template_id
  template_name    = var.template_name

  # Cluster configuration
  master_vm_id       = var.master_vm_id
  master_ip          = var.master_ip
  worker_count       = var.worker_count
  worker_ip_prefix   = var.worker_ip_prefix
  worker_ip_start    = var.worker_ip_start
  gateway_ip         = var.gateway_ip
  cluster_name       = var.cluster_name
  github_branch      = var.github_branch

  # Resource sizing (optional)
  master_cpu_cores = var.master_cpu_cores
  master_memory_mb = var.master_memory_mb
  worker_cpu_cores = var.worker_cpu_cores
  worker_memory_mb = var.worker_memory_mb
  worker_disk_size_gb = var.worker_disk_size_gb
}

output "cluster_name" {
  description = "Kubernetes cluster name"
  value       = module.kubeadm_cluster.cluster_name
}

output "master_vm_id" {
  description = "Master node VM ID"
  value       = module.kubeadm_cluster.master_vm_id
}

output "master_ip" {
  description = "Master node IP address"
  value       = module.kubeadm_cluster.master_ip
}

output "worker_vm_ids" {
  description = "Worker node VM IDs"
  value       = module.kubeadm_cluster.worker_vm_ids
}

output "worker_ips" {
  description = "Worker node IP addresses"
  value       = module.kubeadm_cluster.worker_ips
}
