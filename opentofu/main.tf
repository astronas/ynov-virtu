locals {
  dns_nameserver = join(" ", var.dns_servers)
}

resource "proxmox_vm_qemu" "vm" {
  for_each = var.vms

  name        = each.value.hostname
  description = "${each.value.description} - role=${each.value.role}"
  target_node = var.target_node
  vmid        = try(each.value.vmid, null)

  clone      = var.template_name
  full_clone = true
  os_type    = "cloud-init"

  agent  = 1
  scsihw = "virtio-scsi-pci"
  boot   = "order=scsi0"

  memory = each.value.memory

  cpu {
    cores   = each.value.cores
    sockets = 1
    type    = "host"
  }

  ciuser       = var.ci_user
  cipassword   = var.ci_password
  ipconfig0    = "ip=${each.value.ip}/${each.value.cidr},gw=${var.gateway}"
  nameserver   = local.dns_nameserver
  searchdomain = var.search_domain

  network {
    id       = 0
    model    = "virtio"
    bridge   = var.bridge
    tag      = coalesce(each.value.vlan_id, var.vlan_id)
    firewall = true
  }

  disk {
    type = "ignore"
    slot = "ide0"
  }

  disk {
    type = "ignore"
    slot = "ide2"
  }

  disk {
    type = "ignore"
    slot = "scsi0"
  }

  disk {
    type       = "disk"
    slot       = "scsi1"
    storage    = var.storage
    size       = each.value.disk_size
    discard    = true
    emulatessd = true
  }
}
