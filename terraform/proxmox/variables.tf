# ── Connexion Proxmox ─────────────────────────────────────────────────────────

variable "proxmox_endpoint" {
  description = "URL de l'API Proxmox (nœud maître du cluster)"
  type        = string
  default     = "https://10.0.10.1:8006"
}

variable "proxmox_username" {
  description = "Utilisateur Proxmox API (format user@realm)"
  type        = string
  default     = "terraform@pve"
  sensitive   = true
}

variable "proxmox_password" {
  description = "Mot de passe de l'utilisateur Proxmox API"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Désactiver la validation TLS (certificat auto-signé en lab)"
  type        = bool
  default     = true
}

variable "proxmox_ssh_user" {
  description = "Utilisateur SSH pour les opérations nécessitant un accès direct au nœud"
  type        = string
  default     = "root"
  sensitive   = true
}

variable "proxmox_ssh_password" {
  description = "Mot de passe SSH root des nœuds Proxmox"
  type        = string
  sensitive   = true
}

# ── Nœuds du cluster ─────────────────────────────────────────────────────────

variable "proxmox_nodes" {
  description = "Liste des nœuds Proxmox avec leurs IPs de management"
  type = map(object({
    name       = string
    mgmt_ip    = string
    ceph_pub   = string
    ceph_priv  = optional(string)
    ceph_osd   = bool
    main_iface = string
  }))
  default = {
    prx1 = {
      name       = "prx1"
      mgmt_ip    = "10.0.10.1"
      ceph_pub   = "10.0.101.1"
      ceph_priv  = "10.0.102.1"
      ceph_osd   = true
      main_iface = "nic0"
    }
    prx2 = {
      name       = "prx2"
      mgmt_ip    = "10.0.10.2"
      ceph_pub   = "10.0.101.2"
      ceph_priv  = null
      ceph_osd   = false
      main_iface = "nic0"
    }
    prx3 = {
      name       = "prx3"
      mgmt_ip    = "10.0.10.3"
      ceph_pub   = "10.0.101.3"
      ceph_priv  = "10.0.102.3"
      ceph_osd   = true
      main_iface = "nic0"
    }
  }
}

# ── Stockage ──────────────────────────────────────────────────────────────────

variable "datastore_local" {
  description = "Nom du stockage local Proxmox (pour les disques VM)"
  type        = string
  default     = "local-lvm"
}

variable "datastore_iso" {
  description = "Nom du stockage pour les ISOs"
  type        = string
  default     = "local"
}

variable "datastore_ceph" {
  description = "Nom du pool Ceph Proxmox (défini après init Ceph)"
  type        = string
  default     = "vm-pool"
}

# ── VMs — paramètres communs ──────────────────────────────────────────────────

variable "vm_default_user" {
  description = "Utilisateur cloud-init par défaut pour les VMs Linux"
  type        = string
  default     = "ynov"
  sensitive   = true
}

variable "vm_default_password" {
  description = "Mot de passe cloud-init par défaut (changer en prod)"
  type        = string
  sensitive   = true
}

variable "vm_ssh_public_key" {
  description = "Clé SSH publique injectée via cloud-init dans les VMs"
  type        = string
  sensitive   = true
}

# ── VMs — OPNsense ────────────────────────────────────────────────────────────

variable "opnsense_iso" {
  description = "Chemin de l'ISO OPNsense sur le stockage Proxmox (ex: local:iso/OPNsense-25.1-dvd-amd64.iso)"
  type        = string
  default     = "local:iso/OPNsense-25.1-dvd-amd64.iso"
}

variable "opnsense_node" {
  description = "Nœud Proxmox hébergeant la VM OPNsense"
  type        = string
  default     = "prx3"
}

# ── VMs — DMZ ─────────────────────────────────────────────────────────────────

variable "cloudflared_node" {
  description = "Nœud Proxmox hébergeant la VM cloudflared"
  type        = string
  default     = "prx3"
}

variable "rproxy_node" {
  description = "Nœud Proxmox hébergeant la VM reverse proxy"
  type        = string
  default     = "prx3"
}

variable "linux_cloud_image" {
  description = "ID de l'image cloud-init Linux (template Debian/Ubuntu à créer au préalable)"
  type        = string
  default     = "local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst"
}
