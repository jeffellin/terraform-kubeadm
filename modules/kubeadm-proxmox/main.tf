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

# Generate cluster SSH keypair
resource "tls_private_key" "cluster" {
  algorithm = "ED25519"
}

locals {
  # Extract the last octet from master IP for worker IP calculation
  master_ip_octet = tonumber(split(".", var.master_ip)[3])

  # Determine worker IP start: use provided value, or auto-calculate as master_ip + 1
  worker_ip_start = var.worker_ip_start >= 0 ? var.worker_ip_start : local.master_ip_octet + 1

  # Create worker nodes map with IPs starting after master IP
  worker_nodes = {
    for i in range(1, var.worker_count + 1) : tostring(i) => {
      ip    = local.worker_ip_start + i - 1
      vm_id = local.worker_ip_start + i - 1
    }
  }
}

resource "proxmox_virtual_environment_vm" "k8s_master" {
  count       = 1
  name        = "k8s-master-${count.index + 1}"
  node_name   = var.proxmox_node
  vm_id       = var.master_vm_id

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
    cores = var.master_cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.master_memory_mb
  }

  network_device {
    bridge = var.network_bridge
  }

  initialization {
    user_account {
      username = "ubuntu"
      password = var.vm_password
      keys = compact([
        var.ssh_public_key,
        tls_private_key.cluster.public_key_openssh
      ])
    }

    ip_config {
      ipv4 {
        address = "${var.master_ip}/24"
        gateway = var.gateway_ip
      }
    }

    user_data_file_id = proxmox_virtual_environment_file.master_cloud_init.id
  }

  tags = ["kubernetes", "master", "cluster-${var.cluster_name}"]
}

resource "proxmox_virtual_environment_file" "master_cloud_init" {
  content_type = "snippets"
  datastore_id = var.snippets_storage
  node_name    = var.proxmox_node

  source_raw {
    data = templatefile("${path.module}/master-cloud-init.yaml.tftpl", {
      hostname                  = "k8s-master"
      ssh_public_key            = var.ssh_public_key
      cluster_ssh_key           = tls_private_key.cluster.public_key_openssh
      cluster_ssh_private_key   = tls_private_key.cluster.private_key_openssh
      master_ip                 = var.master_ip
      cluster_name              = var.cluster_name
      branch                    = var.github_branch
    })

    file_name = "master-cloud-init.yaml"
  }

  depends_on = [
    tls_private_key.cluster
  ]
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
    cores = var.worker_cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.worker_memory_mb
  }

  disk {
    datastore_id = var.storage_pool
    interface    = "scsi0"
    size         = var.worker_disk_size_gb
    file_format  = "raw"
  }

  network_device {
    bridge = var.network_bridge
  }

  initialization {
    user_account {
      username = "ubuntu"
      password = var.vm_password
      keys = compact([
        var.ssh_public_key,
        tls_private_key.cluster.public_key_openssh
      ])
    }

    ip_config {
      ipv4 {
        address = "${var.worker_ip_prefix}.${each.value.ip}/24"
        gateway = var.gateway_ip
      }
    }

    user_data_file_id = proxmox_virtual_environment_file.worker_cloud_init[each.key].id
  }

  depends_on = [proxmox_virtual_environment_vm.k8s_master]

  tags = ["kubernetes", "worker", "cluster-${var.cluster_name}"]
}

resource "proxmox_virtual_environment_file" "worker_cloud_init" {
  for_each     = local.worker_nodes
  content_type = "snippets"
  datastore_id = var.snippets_storage
  node_name    = var.proxmox_node

  source_raw {
    data = templatefile("${path.module}/worker-cloud-init.yaml.tftpl", {
      hostname                = "k8s-worker-${each.key}"
      ssh_public_key          = var.ssh_public_key
      cluster_ssh_key         = tls_private_key.cluster.public_key_openssh
      cluster_ssh_private_key = tls_private_key.cluster.private_key_openssh
      master_ip               = var.master_ip
      branch                  = var.github_branch
    })

    file_name = "worker-cloud-init-${each.key}.yaml"
  }

  depends_on = [
    tls_private_key.cluster
  ]
}
