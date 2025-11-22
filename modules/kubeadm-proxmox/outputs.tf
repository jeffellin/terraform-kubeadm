output "master_vm_id" {
  description = "Proxmox VM ID of the master node"
  value       = proxmox_virtual_environment_vm.k8s_master[0].vm_id
}

output "worker_vm_ids" {
  description = "Proxmox VM IDs of the worker nodes"
  value       = { for key, vm in proxmox_virtual_environment_vm.k8s_worker : key => vm.vm_id }
}

output "master_ip" {
  description = "IP address of the Kubernetes master node"
  value       = var.master_ip
}

output "worker_ips" {
  description = "IP addresses of the Kubernetes worker nodes"
  value       = [for key, worker in local.worker_nodes : "${var.worker_ip_prefix}.${worker.ip}"]
}

output "cluster_name" {
  description = "Kubernetes cluster name"
  value       = var.cluster_name
}

output "master_hostname" {
  description = "Master node hostname"
  value       = "k8s-master"
}

output "worker_hostnames" {
  description = "Worker node hostnames"
  value       = { for key in keys(local.worker_nodes) : key => "k8s-worker-${key}" }
}

output "cluster_ssh_private_key" {
  description = "Cluster SSH private key (save this to access VMs)"
  value       = tls_private_key.cluster.private_key_openssh
  sensitive   = true
}
