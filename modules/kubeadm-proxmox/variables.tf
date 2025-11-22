variable "proxmox_host" {
  description = "Proxmox host URL (e.g., https://your-proxmox-host:8006/api2/json)"
  type        = string
}

variable "proxmox_username" {
  description = "Proxmox username (e.g., root@pam)"
  type        = string
}

variable "proxmox_password" {
  description = "Proxmox password"
  type        = string
  sensitive   = true
}

variable "proxmox_node" {
  description = "Proxmox node name where VMs will be created"
  type        = string
}

variable "storage_pool" {
  description = "Proxmox storage pool name for VM disks"
  type        = string
}

variable "network_bridge" {
  description = "Network bridge to use for VMs"
  type        = string
}

variable "vm_password" {
  description = "Password for the ubuntu user on VMs"
  type        = string
  sensitive   = true
  default     = "Passw0rd"
}

variable "ssh_public_key" {
  description = "SSH public key for accessing VMs"
  type        = string
  default     = ""
}

variable "ubuntu_iso_path" {
  description = "Path to Ubuntu ISO image in Proxmox storage"
  type        = string
  default     = "local:iso/ubuntu-24.04-live-server-amd64.iso"
}

variable "template_id" {
  description = "VM ID of the Ubuntu cloud-init template to clone from"
  type        = number
  default     = 9000
}

variable "template_name" {
  description = "Name of the Ubuntu cloud-init template"
  type        = string
  default     = "ubuntu-24.04-cloud-init"
}

variable "snippets_storage" {
  description = "Proxmox storage for snippets (must support snippets content type)"
  type        = string
  default     = "local"
}

variable "worker_count" {
  description = "Number of worker nodes to create"
  type        = number
  default     = 3
}

variable "master_vm_id" {
  description = "VM ID for the master node"
  type        = number
  default     = 200
}

variable "master_ip" {
  description = "IP address for the master node"
  type        = string
  default     = "192.168.1.200"
}

variable "worker_ip_prefix" {
  description = "IP prefix for worker nodes (e.g., 192.168.1)"
  type        = string
  default     = "192.168.1"
}

variable "worker_ip_start" {
  description = "Starting IP octet for first worker node. Use -1 to auto-calculate as master_ip_octet + 1"
  type        = number
  default     = -1
}

variable "gateway_ip" {
  description = "Gateway IP address for the network"
  type        = string
  default     = "192.168.1.1"
}

variable "master_cpu_cores" {
  description = "Number of CPU cores for master node"
  type        = number
  default     = 2
}

variable "master_memory_mb" {
  description = "Memory in MB for master node"
  type        = number
  default     = 4096
}

variable "worker_cpu_cores" {
  description = "Number of CPU cores for worker nodes"
  type        = number
  default     = 2
}

variable "worker_memory_mb" {
  description = "Memory in MB for worker nodes"
  type        = number
  default     = 8192
}

variable "worker_disk_size_gb" {
  description = "Disk size in GB for worker nodes"
  type        = number
  default     = 50
}

variable "cluster_name" {
  description = "Kubernetes cluster name"
  type        = string
  default     = "k8s-cluster"
}

variable "github_branch" {
  description = "GitHub branch for init scripts (e.g., main, develop, feature-branch)"
  type        = string
  default     = "main"
}
