resource "proxmox_virtual_environment_vm" "this" {
  name      = var.name
  node_name = var.node_name
  vm_id     = var.vm_id
  tags      = var.tags

  on_boot = true
  started = true

  cpu {
    cores   = var.cpu_cores
    sockets = 1
    type    = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.memory
  }

  # Disque OS depuis image cloud-init
  disk {
    datastore_id = var.datastore_id
    size         = var.disk_size
    interface    = "scsi0"
    iothread     = true
    discard      = "on"
    file_format  = "raw"
  }

  # Interfaces réseau (liste dynamique)
  dynamic "network_device" {
    for_each = var.network_devices
    content {
      bridge  = network_device.value.bridge
      model   = network_device.value.model
      vlan_id = lookup(network_device.value, "vlan_id", null)
    }
  }

  operating_system {
    type = "l26" # Linux 2.6+
  }

  agent {
    enabled = true # qemu-guest-agent installé via cloud-init
  }

  # Cloud-init
  initialization {
    user_account {
      username = var.cloud_init_user
      password = var.cloud_init_password
      keys     = [var.ssh_public_key]
    }

    ip_config {
      ipv4 {
        address = var.ipv4_address
        gateway = var.ipv4_gateway
      }
    }

    dns {
      servers = ["10.0.10.254", "1.1.1.1"]
    }
  }
}
