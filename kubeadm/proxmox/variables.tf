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
  default     = "pve"
}

variable "ubuntu_iso_path" {
  description = "Path to Ubuntu ISO image in Proxmox storage"
  type        = string
}

variable "template_name" {
  description = "Name of the Ubuntu cloud-init template to clone from"
  type        = string
}

variable "template_id" {
  description = "VM ID of the Ubuntu cloud-init template to clone from"
  type        = number
  default     = 9000
}

variable "storage_pool" {
  description = "Proxmox storage pool name"
  type        = string
  default     = "SSD_2TB_1"
}

variable "snippets_storage" {
  description = "Proxmox storage for snippets (must support snippets content type)"
  type        = string
  default     = "local"
}

variable "network_bridge" {
  description = "Network bridge to use for VMs"
  type        = string
  default     = "vmbr0"
}

variable "vm_password" {
  description = "Password for the ubuntu user on VMs"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "SSH public key for accessing VMs"
  type        = string
}

