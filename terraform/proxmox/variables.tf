# ── Connexion Proxmox ─────────────────────────────────────────────────────────

variable "proxmox_api_url" {
  description = "URL de l'API Proxmox (avec /api2/json)"
  type        = string
  default     = "https://10.0.10.1:8006/api2/json"
}

variable "proxmox_api_token_id" {
  description = "ID du token API Proxmox (format: user@realm!tokenid)"
  type        = string
  sensitive   = true
}

variable "proxmox_api_token_secret" {
  description = "Secret UUID du token API Proxmox"
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Désactiver la validation TLS (certificat auto-signé en lab)"
  type        = bool
  default     = true
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

# ── VMs — déploiement par clone de template ───────────────────────────────────

variable "default_template" {
  description = "Template à cloner par défaut quand une VM n'en précise pas"
  type        = string
  default     = "tmpl-debian"
}

# Valeurs cloud-init par défaut (surchargées par VM si besoin)
variable "ci_default_user" {
  description = "Utilisateur cloud-init par défaut"
  type        = string
  default     = "debian"
}

variable "ci_default_password" {
  description = "Mot de passe cloud-init par défaut"
  type        = string
  default     = ""
  sensitive   = true
}

variable "ci_default_ssh_key" {
  description = "Clé SSH publique par défaut injectée par cloud-init"
  type        = string
  default     = ""
}

variable "ci_nameserver" {
  description = "DNS injecté par cloud-init (séparés par espaces)"
  type        = string
  default     = "10.0.10.254 1.1.1.1"
}

variable "vms" {
  description = "Map des VMs à déployer (clé = identifiant logique)"
  type = map(object({
    vm_id     = number
    name      = string
    node      = string
    template  = optional(string)         # défaut: var.default_template
    cpu_cores = optional(number, 2)
    memory    = optional(number, 2048)   # Mo
    disk_size = optional(number, 48)     # Go — doit être >= disque du template (48G)
    datastore = optional(string)         # défaut: var.datastore_local
    tags      = optional(list(string), [])
    networks = optional(list(object({
      bridge  = optional(string, "vmbr0")
      model   = optional(string, "virtio")
      vlan_id = optional(number)
    })), [])
    # Cloud-init
    ipv4_address   = optional(string, "dhcp") # CIDR (ex: 10.0.30.40/24) ou "dhcp"
    ipv4_gateway   = optional(string, "")
    ci_user        = optional(string)         # défaut: var.ci_default_user
    ci_password    = optional(string)         # défaut: var.ci_default_password
    ssh_public_key = optional(string)         # défaut: var.ci_default_ssh_key
  }))
  default = {}
}

