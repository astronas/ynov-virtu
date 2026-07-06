locals {
  dns_nameserver = join(" ", var.dns_servers)
}

# --- NetBox comme allocateur d'IP (source de verite IPAM) --------------------
# Pour chaque VM SANS `ip` statique, on demande a NetBox la prochaine IP libre du
# `prefix` indique. Les VMs avec `ip` renseignee restent statiques (ex: netbox
# elle-meme, pour ne pas creer de dependance circulaire tofu <-> NetBox).
data "netbox_prefix" "vm" {
  for_each = { for k, v in var.vms : k => v if v.ip == null }
  prefix   = each.value.prefix
}

resource "netbox_available_ip_address" "vm" {
  for_each  = { for k, v in var.vms : k => v if v.ip == null }
  prefix_id = data.netbox_prefix.vm[each.key].id
  status    = "active"
  dns_name  = "${each.value.hostname}.${var.search_domain}"
}

locals {
  # IP CIDR finale par VM : statique ("ip/cidr") ou allouee par NetBox (deja en CIDR).
  vm_ip_cidr = {
    for k, v in var.vms : k => (
      v.ip != null ? "${v.ip}/${v.cidr}" : netbox_available_ip_address.vm[k].ip_address
    )
  }
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
  ipconfig0    = "ip=${local.vm_ip_cidr[each.key]},gw=${var.gateway}"
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
