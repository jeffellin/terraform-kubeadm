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
      keys     = [var.ssh_public_key]
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
    data = <<-EOF
    #cloud-config
    package_upgrade: true
    packages:
      - qemu-guest-agent
    ssh_pwauth: true
    chpasswd:
      expire: false
    runcmd:
      - systemctl enable qemu-guest-agent
      - systemctl start qemu-guest-agent
      - curl -fsSL https://raw.githubusercontent.com/jeffellin/terraform-kubeadm/main/kubeadm/shared/install-k8s-common.sh | bash
      - sleep 30
      - curl -fsSL https://raw.githubusercontent.com/jeffellin/terraform-kubeadm/main/kubeadm/shared/init-k8s-master.sh | bash -s -- 192.168.1.200 k8s-cluster
    EOF

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
      keys     = [var.ssh_public_key]
    }

    ip_config {
      ipv4 {
        address = "192.168.1.${201 + count.index}/24"
        gateway = "192.168.1.1"
      }
    }

    user_data_file_id = proxmox_virtual_environment_file.worker_cloud_init.id
  }

  depends_on = [proxmox_virtual_environment_vm.k8s_master]

  tags = ["kubernetes", "worker"]
}

resource "proxmox_virtual_environment_file" "worker_cloud_init" {
  content_type = "snippets"
  datastore_id = var.snippets_storage
  node_name    = var.proxmox_node

  source_raw {
    data = <<-EOF
    #cloud-config
    package_upgrade: true
    packages:
      - qemu-guest-agent
    ssh_pwauth: true
    chpasswd:
      expire: false
    runcmd:
      - systemctl enable qemu-guest-agent
      - systemctl start qemu-guest-agent
      - curl -fsSL https://raw.githubusercontent.com/jeffellin/terraform-kubeadm/main/kubeadm/shared/install-k8s-common.sh | bash
      - sleep 120
      - curl -fsSL https://raw.githubusercontent.com/jeffellin/terraform-kubeadm/main/kubeadm/shared/join-k8s-worker.sh | bash -s -- 192.168.1.200
    EOF

    file_name = "worker-cloud-init.yaml"
  }
}