# Module VM générique — clone d'un template cloud-init (telmate/proxmox v3)
#
# La VM est clonée depuis un template, puis cloud-init injecte l'IP statique,
# l'utilisateur et la clé SSH au premier boot.
#
# PRÉREQUIS sur le template :
#   - paquet `cloud-init` installé dans l'invité Debian
#   - le disque OS sur scsi0

resource "proxmox_vm_qemu" "this" {
  name        = var.name
  target_node = var.node_name
  vmid        = var.vm_id
  tags        = join(",", var.tags)

  # Clone d'un template existant
  clone      = var.clone_template
  full_clone = true

  start_at_node_boot = true

  # Pas d'attente sur le guest agent : il n'est pas garanti dans le template,
  # ce qui provoquerait "Qemu guest not running".
  agent = 0

  memory = var.memory

  cpu {
    cores   = var.cpu_cores
    sockets = 1
    type    = "x86-64-v2-AES"
  }

  scsihw = "virtio-scsi-single"

  # Boot sur le 1er disque cloné depuis le template.
  boot = "order=scsi0"

  # ── Cloud-init ──────────────────────────────────────────────────────────────
  os_type    = "cloud-init"
  ciuser     = var.cloud_init_user
  cipassword = var.cloud_init_password
  sshkeys    = var.ssh_public_key
  nameserver = var.nameserver

  # IP statique injectée par cloud-init (ou "dhcp")
  ipconfig0 = var.ipv4_address == "dhcp" ? "ip=dhcp" : "ip=${var.ipv4_address}${var.ipv4_gateway != "" ? ",gw=${var.ipv4_gateway}" : ""}"

  # telmate v3 gère TOUS les disques : il faut déclarer le disque du clone,
  # sinon il le supprime (et casse le boot scsi0). Le template `tmpl-debian`
  # a un unique disque OS sur scsi0.
  disks {
    scsi {
      scsi0 {
        disk {
          storage = var.datastore_id
          size    = var.disk_size
        }
      }
    }
    ide {
      ide2 {
        cloudinit {
          storage = var.datastore_id
        }
      }
    }
  }

  dynamic "network" {
    for_each = var.network_devices
    content {
      id     = network.key
      model  = network.value.model
      bridge = network.value.bridge
      tag    = lookup(network.value, "vlan_id", 0)
    }
  }

  lifecycle {
    # On laisse cloud-init / le clone gérer les disques scsi ; Terraform ne
    # doit pas tenter de les reconfigurer.
    ignore_changes = [network]
  }
}
