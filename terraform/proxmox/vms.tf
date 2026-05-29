# ──────────────────────────────────────────────────────────────────────────────
# VMs du lab — bpg/proxmox provider
#
# VMs gérées :
#   100 — OPNsense  (PRX3, VLAN 99/10/20/30) — installation manuelle via ISO
#   101 — cloudflared (PRX3, DMZ VLAN 20)    — cloud-init Debian
#   102 — reverse-proxy (PRX3, DMZ VLAN 20)  — cloud-init Debian
# ──────────────────────────────────────────────────────────────────────────────

# ── VM 100 : OPNsense ─────────────────────────────────────────────────────────
# Crée la VM avec l'ISO monté. L'installation OPNsense se fait manuellement
# depuis la console Proxmox (noVNC). La VM est laissée arrêtée (started=false).

resource "proxmox_virtual_environment_vm" "opnsense" {
  name      = "opnsense"
  node_name = var.opnsense_node
  vm_id     = 100
  tags      = ["opnsense", "firewall", "critical"]

  on_boot = true
  started = false # démarrer manuellement après installation ISO

  cpu {
    cores   = 2
    sockets = 1
    type    = "x86-64-v2-AES"
  }

  memory {
    dedicated = 4096
    floating  = 512
  }

  disk {
    datastore_id = var.datastore_local
    size         = 20
    interface    = "scsi0"
    iothread     = true
    discard      = "on"
    file_format  = "raw"
  }

  cdrom {
    enabled = true
    file_id = var.opnsense_iso
  }

  # net0 — WAN (VLAN 99)
  network_device {
    bridge  = "vmbr0"
    model   = "virtio"
    vlan_id = local.vlan_wan
  }

  # net1 — LAN/MGMT (VLAN 10, non tagué = natif sur le trunk)
  network_device {
    bridge = "vmbr0"
    model  = "virtio"
    # pas de vlan_id = trafic natif VLAN 10
  }

  # net2 — DMZ (VLAN 20)
  network_device {
    bridge  = "vmbr0"
    model   = "virtio"
    vlan_id = local.vlan_dmz
  }

  # net3 — SRV/LAN (VLAN 30)
  network_device {
    bridge  = "vmbr0"
    model   = "virtio"
    vlan_id = local.vlan_srv
  }

  operating_system {
    type = "other" # FreeBSD
  }

  # Empêcher Terraform de recréer la VM si le disque change (post-install)
  lifecycle {
    ignore_changes = [cdrom, disk, started]
  }
}

# ── VM 101 : cloudflared (DMZ) ────────────────────────────────────────────────

module "vm_cloudflared" {
  source = "./modules/vm"

  vm_id     = 101
  name      = "cloudflared"
  node_name = var.cloudflared_node
  tags      = ["cloudflared", "dmz", "tunnel"]

  cpu_cores = 1
  memory    = 512

  disk_size    = 8
  datastore_id = var.datastore_local

  # Interface DMZ uniquement
  network_devices = [
    {
      bridge  = "vmbr0"
      vlan_id = local.vlan_dmz
      model   = "virtio"
    }
  ]

  cloud_init_user     = var.vm_default_user
  cloud_init_password = var.vm_default_password
  ssh_public_key      = var.vm_ssh_public_key

  # IP statique VLAN 20
  ipv4_address = "10.0.20.5/24"
  ipv4_gateway = "10.0.20.254"
}

# ── VM 102 : reverse-proxy (DMZ) ──────────────────────────────────────────────

module "vm_reverse_proxy" {
  source = "./modules/vm"

  vm_id     = 102
  name      = "reverse-proxy"
  node_name = var.rproxy_node
  tags      = ["nginx", "dmz", "proxy"]

  cpu_cores = 2
  memory    = 1024

  disk_size    = 16
  datastore_id = var.datastore_local

  network_devices = [
    {
      bridge  = "vmbr0"
      vlan_id = local.vlan_dmz
      model   = "virtio"
    }
  ]

  cloud_init_user     = var.vm_default_user
  cloud_init_password = var.vm_default_password
  ssh_public_key      = var.vm_ssh_public_key

  # IP statique VLAN 20
  ipv4_address = "10.0.20.10/24"
  ipv4_gateway = "10.0.20.254"
}

# ── VM 110 : vm-template SRV-LAN (exemple) ────────────────────────────────────
# Décommenter et dupliquer pour ajouter des VMs dans le VLAN SRV/LAN.
#
# module "vm_srv_example" {
#   source = "./modules/vm"
#
#   vm_id     = 110
#   name      = "srv-example"
#   node_name = "prx1"
#   tags      = ["srv", "lan"]
#
#   cpu_cores = 2
#   memory    = 2048
#   disk_size    = 32
#   datastore_id = var.datastore_ceph   # stockage Ceph pour les VMs SRV
#
#   network_devices = [{
#     bridge  = "vmbr0"
#     vlan_id = local.vlan_srv
#     model   = "virtio"
#   }]
#
#   cloud_init_user     = var.vm_default_user
#   cloud_init_password = var.vm_default_password
#   ssh_public_key      = var.vm_ssh_public_key
#   ipv4_address = "10.0.30.10/24"
#   ipv4_gateway = "10.0.30.254"
# }
