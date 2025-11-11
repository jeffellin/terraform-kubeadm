terraform {
  required_version = ">= 1.0"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.40.0"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_host
  username = var.proxmox_username
  password = var.proxmox_password
  insecure = true
}

resource "proxmox_virtual_environment_vm" "k8s_master" {
  count       = 1
  name        = "k8s-master-${count.index + 1}"
  node_name   = var.proxmox_node
  vm_id       = 200

  clone {
    vm_id = var.template_id
    full  = true
  }

  agent {
    enabled = true
    timeout = "5m"
  }

  started = true

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 4096
  }

  network_device {
    bridge = var.network_bridge
  }

  initialization {
    user_account {
      username = "ubuntu"
      password = var.vm_password
      keys     = [
        var.ssh_public_key,
        file("${path.module}/cluster-ssh-key.pub")
      ]
    }

    ip_config {
      ipv4 {
        address = "192.168.1.200/24"
        gateway = "192.168.1.1"
      }
    }

    user_data_file_id = proxmox_virtual_environment_file.master_cloud_init.id
  }

  tags = ["kubernetes", "master"]
}

resource "proxmox_virtual_environment_file" "master_cloud_init" {
  content_type = "snippets"
  datastore_id = var.snippets_storage
  node_name    = var.proxmox_node

  source_raw {
    data = templatefile("${path.module}/master-cloud-init.yaml.tftpl", {
      hostname = "k8s-master"
      ssh_public_key = var.ssh_public_key
      cluster_ssh_key = file("${path.module}/cluster-ssh-key.pub")
      cluster_ssh_private_key = file("${path.module}/cluster-ssh-key")
    })

    file_name = "master-cloud-init.yaml"
  }
}

locals {
  worker_nodes = {
    "1" = { ip = 201, vm_id = 201 }
    "2" = { ip = 202, vm_id = 202 }
    "3" = { ip = 203, vm_id = 203 }
  }
}

resource "proxmox_virtual_environment_vm" "k8s_worker" {
  for_each    = local.worker_nodes
  name        = "k8s-worker-${each.key}"
  node_name   = var.proxmox_node
  vm_id       = each.value.vm_id

  clone {
    vm_id = var.template_id
    full  = true
  }

  agent {
    enabled = true
    timeout = "5m"
  }

  started = true

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 8192
  }

  disk {
    datastore_id = var.storage_pool
    interface    = "scsi0"
    size         = 50
    file_format  = "raw"
  }

  network_device {
    bridge = var.network_bridge
  }

  initialization {
    user_account {
      username = "ubuntu"
      password = var.vm_password
      keys     = [
        var.ssh_public_key,
        file("${path.module}/cluster-ssh-key.pub")
      ]
    }

    ip_config {
      ipv4 {
        address = "192.168.1.${each.value.ip}/24"
        gateway = "192.168.1.1"
      }
    }

    user_data_file_id = proxmox_virtual_environment_file.worker_cloud_init[each.key].id
  }

  depends_on = [proxmox_virtual_environment_vm.k8s_master]

  tags = ["kubernetes", "worker"]
}

resource "proxmox_virtual_environment_file" "worker_cloud_init" {
  for_each     = local.worker_nodes
  content_type = "snippets"
  datastore_id = var.snippets_storage
  node_name    = var.proxmox_node

  source_raw {
    data = templatefile("${path.module}/worker-cloud-init.yaml.tftpl", {
      hostname = "k8s-worker-${each.key}"
      ssh_public_key = var.ssh_public_key
      cluster_ssh_key = file("${path.module}/cluster-ssh-key.pub")
      cluster_ssh_private_key = file("${path.module}/cluster-ssh-key")
    })

    file_name = "worker-cloud-init-${each.key}.yaml"
  }
}