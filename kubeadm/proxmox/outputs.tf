output "master_vm_id" {
  description = "Proxmox VM ID of the master node"
  value       = proxmox_virtual_environment_vm.k8s_master[0].vm_id
}

output "worker_vm_ids" {
  description = "Proxmox VM IDs of the worker nodes"
  value       = proxmox_virtual_environment_vm.k8s_worker[*].vm_id
}

output "master_ip" {
  description = "IP address of the Kubernetes master node"
  value       = "192.168.1.200"
}

output "worker_ips" {
  description = "IP addresses of the Kubernetes worker nodes"
  value       = ["192.168.1.201", "192.168.1.202"]
}