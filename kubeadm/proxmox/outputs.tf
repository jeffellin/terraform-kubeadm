output "master_ip" {
  description = "IP address of the Kubernetes master node"
  value       = proxmox_vm_qemu.k8s_master[0].default_ipv4_address
}

output "worker_ips" {
  description = "IP addresses of the Kubernetes worker nodes"
  value       = proxmox_vm_qemu.k8s_worker[*].default_ipv4_address
}

output "master_vm_id" {
  description = "Proxmox VM ID of the master node"
  value       = proxmox_vm_qemu.k8s_master[0].vmid
}

output "worker_vm_ids" {
  description = "Proxmox VM IDs of the worker nodes"
  value       = proxmox_vm_qemu.k8s_worker[*].vmid
}

output "cluster_endpoint" {
  description = "Kubernetes cluster API endpoint"
  value       = "https://${proxmox_vm_qemu.k8s_master[0].default_ipv4_address}:6443"
}

output "ssh_command_master" {
  description = "SSH command to connect to the master node"
  value       = "ssh ubuntu@${proxmox_vm_qemu.k8s_master[0].default_ipv4_address}"
}

output "ssh_commands_workers" {
  description = "SSH commands to connect to worker nodes"
  value       = [for vm in proxmox_vm_qemu.k8s_worker : "ssh ubuntu@${vm.default_ipv4_address}"]
}