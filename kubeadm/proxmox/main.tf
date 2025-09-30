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

resource "proxmox_virtual_environment_vm" "k8s_worker" {
  count       = 2
  name        = "k8s-worker-${count.index + 1}"
  node_name   = var.proxmox_node
  vm_id       = 201 + count.index

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
    dedicated = 2048
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
        address = "192.168.1.${201 + count.index}/24"
        gateway = "192.168.1.1"
      }
    }

    user_data_file_id = proxmox_virtual_environment_file.worker_cloud_init[count.index].id
  }

  depends_on = [proxmox_virtual_environment_vm.k8s_master]

  tags = ["kubernetes", "worker"]
}

resource "proxmox_virtual_environment_file" "worker_cloud_init" {
  count        = 2
  content_type = "snippets"
  datastore_id = var.snippets_storage
  node_name    = var.proxmox_node

  source_raw {
    data = templatefile("${path.module}/worker-cloud-init.yaml.tftpl", {
      hostname = "k8s-worker-${count.index + 1}"
      ssh_public_key = var.ssh_public_key
      cluster_ssh_key = file("${path.module}/cluster-ssh-key.pub")
      cluster_ssh_private_key = file("${path.module}/cluster-ssh-key")
    })

    file_name = "worker-cloud-init-${count.index + 1}.yaml"
  }
}