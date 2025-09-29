terraform {
  required_version = ">= 1.0"
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "~> 2.9"
    }
  }
}

provider "proxmox" {
  pm_api_url      = var.proxmox_host
  pm_user         = var.proxmox_username
  pm_password     = var.proxmox_password
  pm_tls_insecure = true
}

resource "proxmox_vm_qemu" "k8s_master" {
  count       = 1
  name        = "k8s-master-${count.index + 1}"
  target_node = var.proxmox_node
  clone       = var.template_name
  vmid        = 200

  cores    = 2
  sockets  = 1
  memory   = 4096

  disk {
    slot    = 0
    size    = "20G"
    type    = "scsi"
    storage = var.storage_pool
  }

  network {
    model  = "virtio"
    bridge = var.network_bridge
  }

  os_type = "cloud-init"

  ciuser     = "ubuntu"
  cipassword = var.vm_password
  sshkeys    = var.ssh_public_key

  ipconfig0 = "ip=dhcp"

  connection {
    type     = "ssh"
    user     = "ubuntu"
    password = var.vm_password
    host     = self.default_ipv4_address
  }

  # Copy shared scripts
  provisioner "file" {
    source      = "${path.module}/../shared/"
    destination = "/tmp/scripts"
  }

  # Run installation
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/scripts/*.sh",
      "/tmp/scripts/install-k8s-common.sh",
      "/tmp/scripts/init-k8s-master.sh ${self.default_ipv4_address} k8s-cluster"
    ]
  }

  tags = "kubernetes,master"
}

resource "proxmox_vm_qemu" "k8s_worker" {
  count       = 2
  name        = "k8s-worker-${count.index + 1}"
  target_node = var.proxmox_node
  clone       = var.template_name
  vmid        = 201 + count.index

  cores    = 2
  sockets  = 1
  memory   = 2048

  disk {
    slot    = 0
    size    = "20G"
    type    = "scsi"
    storage = var.storage_pool
  }

  network {
    model  = "virtio"
    bridge = var.network_bridge
  }

  os_type = "cloud-init"

  ciuser     = "ubuntu"
  cipassword = var.vm_password
  sshkeys    = var.ssh_public_key

  ipconfig0 = "ip=dhcp"

  depends_on = [proxmox_vm_qemu.k8s_master]

  connection {
    type     = "ssh"
    user     = "ubuntu"
    password = var.vm_password
    host     = self.default_ipv4_address
  }

  # Copy shared scripts
  provisioner "file" {
    source      = "${path.module}/../shared/"
    destination = "/tmp/scripts"
  }

  # Run installation
  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/scripts/*.sh",
      "/tmp/scripts/install-k8s-common.sh",
      "sleep 60", # Wait for master to be ready
      "/tmp/scripts/join-k8s-worker.sh ${proxmox_vm_qemu.k8s_master[0].default_ipv4_address}"
    ]
  }

  tags = "kubernetes,worker"
}